self:
{ config, options, lib, pkgs, ... }:

# One module for both nix-darwin (launchd) and NixOS (systemd). The platform is
# detected from the declared options rather than `pkgs`, which would recurse.
with lib;
let
  cfg = config.services.rayfish;
  isDarwin = options ? launchd;

  # `sudo ray-fix`: point the Rayfish DNS (200::53) and active peer routes back at
  # the Rayfish utun, after Rayfish or another VPN (e.g. WARP) replaces a utun
  # interface or address.
  rayFix = pkgs.writeShellScriptBin "ray-fix" ''
    set -eu
    [ "$(id -u)" -eq 0 ] || { echo "ray-fix: run with sudo" >&2; exit 1; }
    ray=${cfg.package}/libexec/rayfish/ray
    status="$($ray status --json 2>/dev/null || true)"
    [ -n "$status" ] || { echo "ray-fix: rayfish daemon not answering" >&2; exit 1; }

    local_ip="$(printf '%s' "$status" | ${pkgs.jq}/bin/jq -r '.networks[]?.my_ipv6 // empty' | /usr/bin/head -n 1)"
    [ -n "$local_ip" ] || { echo "ray-fix: no rayfish address yet" >&2; exit 1; }

    utun=""
    for dev in $(/sbin/ifconfig -l | /usr/bin/tr ' ' '\n' | /usr/bin/grep '^utun' || true); do
      if /sbin/ifconfig "$dev" 2>/dev/null | /usr/bin/grep -q "inet6 $local_ip "; then
        utun="$dev"
        break
      fi
    done
    [ -n "$utun" ] || { echo "ray-fix: no utun has $local_ip" >&2; exit 1; }

    ensure_route() {
      target="$1"
      current="$(/sbin/route -n get -inet6 "$target" 2>/dev/null | /usr/bin/awk '/interface:/{print $2; exit}' || true)"
      if [ "$current" != "$utun" ]; then
        [ -z "$current" ] || /sbin/route -n delete -inet6 "$target" >/dev/null 2>&1 || true
        /sbin/route -n add -inet6 "$target" -interface "$utun" >/dev/null 2>&1 || true
        echo "$target -> $utun (was ''${current:-none})"
      fi
    }

    ensure_route 200::53
    printf '%s' "$status" | ${pkgs.jq}/bin/jq -r '
      .networks[]?.peers[]? |
      select(.state == "Active" and .ipv6 != null) | .ipv6' |
      while read -r peer; do
        [ -z "$peer" ] || ensure_route "$peer"
      done
  '';
in {
  options.services.rayfish = {
    enable = mkEnableOption "Rayfish mesh VPN";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.rayfish;
      defaultText = literalExpression "retpel.packages.\${pkgs.stdenv.hostPlatform.system}.rayfish";
      description = "Rayfish package to run.";
    };
    resolver.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Send `.ray` DNS queries to Rayfish's resolver (200::53), so they don't
        go to another VPN's local resolver. On macOS this writes
        /etc/resolver/ray. On NixOS it enables systemd-resolved, and Rayfish's
        Magic DNS puts 200::53 and its .ray domains on rayfish0 through
        resolved's D-Bus API. With another VPN owning /etc/resolv.conf (e.g.
        WARP), Rayfish also adds 200::53 ahead of that VPN's resolver there.
      '';
    };
    rayFix.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install `ray-fix`, a sudo command that points the Rayfish DNS and
        active peer routes back at the Rayfish utun after another VPN
        replaces a utun interface or address. macOS only.
      '';
    };
    logFilter = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "info,iroh::net_report=error";
      description = ''
        `RUST_LOG` for the daemon. Rayfish's defaults are `info` for its main
        output (journal / /var/log/rayfish.log) and `info,rayfish=debug` for its
        daily file log; `RUST_LOG` replaces both. The example drops iroh's
        network-report warnings (e.g. "IPv4 address detected by QAD varies by
        destination" behind hard NAT) at the cost of Rayfish's debug detail in
        the file log. `null` keeps Rayfish's defaults.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    { environment.systemPackages = [ cfg.package ]; }

    (optionalAttrs isDarwin {
      environment.systemPackages = optional cfg.rayFix.enable rayFix;

      environment.etc."resolver/ray" = mkIf cfg.resolver.enable {
        text = ''
          nameserver 200::53
          timeout 1
          attempts 2
        '';
      };

      launchd.daemons.rayfish = {
        serviceConfig = {
          Label = "com.rayfish.vpn";
          # LaunchDaemons can start before the Nix store is mounted during
          # boot. Wait from the system shell instead of letting launchd cache a
          # missing executable and mark the job failed.
          ProgramArguments = [
            "/bin/sh"
            "-c"
            ''
              while [ ! -x "${cfg.package}/libexec/rayfish/ray" ]; do sleep 1; done
              exec "${cfg.package}/libexec/rayfish/ray" daemon
            ''
          ];
          RunAtLoad = true;
          # Restart after a failed daemon exit instead of leaving the service in
          # launchd's penalty box.
          KeepAlive = {
            SuccessfulExit = false;
          };
          ThrottleInterval = 10;
          StandardOutPath = "/var/log/rayfish.log";
          StandardErrorPath = "/var/log/rayfish.log";
        }
        // optionalAttrs (cfg.logFilter != null) {
          EnvironmentVariables.RUST_LOG = cfg.logFilter;
        };
      };
    })

    (optionalAttrs (!isDarwin) {
      services.resolved.enable = mkIf cfg.resolver.enable (mkDefault true);

      systemd.services.rayfish = {
        description = "Rayfish mesh VPN daemon";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = "${cfg.package}/libexec/rayfish/ray daemon";
          Restart = "on-failure";
          RestartSec = 5;
          User = "root";
        };
        environment = optionalAttrs (cfg.logFilter != null) { RUST_LOG = cfg.logFilter; };
      };
    })
  ]);
}
