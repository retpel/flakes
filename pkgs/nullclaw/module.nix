self:
{ config, options, lib, pkgs, ... }:

# One module for both nix-darwin (launchd) and NixOS (systemd), like rayfish.
# Runs what `nullclaw service install` sets up upstream (`nullclaw gateway`,
# restart on exit, NULLCLAW_HOME, optional .env), but pointed at the Nix
# package instead of the store path of whatever binary ran `service install`,
# which goes stale on update and disappears on GC.
with lib;
let
  cfg = config.services.nullclaw;
  isDarwin = options ? launchd;
  home = config.users.users.${cfg.user}.home;
in {
  options.services.nullclaw = {
    enable = mkEnableOption "the NullClaw gateway (runs an autonomous AI agent as `user`)";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.nullclaw;
      defaultText = literalExpression "retpel.packages.\${pkgs.stdenv.hostPlatform.system}.nullclaw";
      description = "NullClaw package to run, e.g. `nullclaw-nightly`.";
    };
    user = mkOption {
      type = types.str;
      example = "alice";
      description = ''
        User the gateway runs as. Its config, credentials and workspace live in
        `stateDir`, created by `nullclaw onboard` as this user.
      '';
    };
    stateDir = mkOption {
      type = types.str;
      default = "${home}/.nullclaw";
      defaultText = literalExpression ''"''${config.users.users.<user>.home}/.nullclaw"'';
      description = "NullClaw home (NULLCLAW_HOME): config.json, auth.json, workspace.";
    };
    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = "${cfg.stateDir}/.env";
      defaultText = literalExpression ''"''${stateDir}/.env"'';
      description = ''
        Optional KEY=value file loaded into the gateway's environment, e.g.
        provider API keys. Skipped when missing. On macOS it is sourced by
        the launcher shell.
      '';
    };
    watchdog = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Restart the gateway when one of its polling channels (e.g. Telegram)
          gets stuck. NullClaw restarts a stale channel thread itself, but that
          restart joins the old thread and hangs forever if the thread is stuck
          in a request: the process stays up and `Restart=always` never fires.
          A timer checks the current run's log for the stale/health warning and
          restarts the whole service. NixOS only.
        '';
      };
      interval = mkOption {
        type = types.str;
        default = "5min";
        description = "How often the watchdog checks (systemd time span).";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    { environment.systemPackages = [ cfg.package ]; }

    (optionalAttrs isDarwin {
      launchd.daemons.nullclaw = {
        serviceConfig = {
          Label = "com.nullclaw.gateway";
          UserName = cfg.user;
          # Like rayfish: wait for the Nix store at boot instead of letting
          # launchd cache a missing executable.
          ProgramArguments = [
            "/bin/sh"
            "-c"
            ''
              while [ ! -x "${cfg.package}/bin/nullclaw" ]; do sleep 1; done
              ${optionalString (cfg.environmentFile != null) ''
                if [ -r "${cfg.environmentFile}" ]; then set -a; . "${cfg.environmentFile}"; set +a; fi
              ''}
              exec "${cfg.package}/bin/nullclaw" gateway
            ''
          ];
          EnvironmentVariables = {
            HOME = home;
            NULLCLAW_HOME = cfg.stateDir;
            # The agent runs tools (git, shell): the same programs as a login shell.
            PATH = concatStringsSep ":" [
              "/etc/profiles/per-user/${cfg.user}/bin"
              "/run/current-system/sw/bin"
              "/nix/var/nix/profiles/default/bin"
              "/usr/bin"
              "/bin"
              "/usr/sbin"
              "/sbin"
            ];
          };
          WorkingDirectory = home;
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          StandardOutPath = "${cfg.stateDir}/gateway.log";
          StandardErrorPath = "${cfg.stateDir}/gateway.log";
        };
      };
    })

    (optionalAttrs (!isDarwin) {
      systemd.services.nullclaw = {
        description = "NullClaw gateway";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        # The agent runs tools (git, shell): the same programs as a login shell.
        path = [
          "/run/wrappers"
          "/etc/profiles/per-user/${cfg.user}"
          "/run/current-system/sw"
        ];
        environment = {
          HOME = home;
          NULLCLAW_HOME = cfg.stateDir;
        };
        serviceConfig = {
          User = cfg.user;
          Group = config.users.users.${cfg.user}.group;
          WorkingDirectory = home;
          ExecStart = "${cfg.package}/bin/nullclaw gateway";
          EnvironmentFile = optional (cfg.environmentFile != null) "-${cfg.environmentFile}";
          Restart = "always";
          RestartSec = 3;
        };
      };

      # Only this run's log (by invocation ID), so the restart it triggers
      # starts clean and cannot loop on an old warning.
      systemd.services.nullclaw-watchdog = mkIf cfg.watchdog.enable {
        description = "Restart NullClaw when a channel is stuck";
        serviceConfig.Type = "oneshot";
        script = ''
          systemctl is-active --quiet nullclaw.service || exit 0
          id=$(systemctl show --property=InvocationID --value nullclaw.service)
          [ -n "$id" ] || exit 0
          if journalctl --quiet --output=cat _SYSTEMD_INVOCATION_ID="$id" \
              | grep -qE ' issue: (polling thread stale|health check failed)'; then
            echo "nullclaw: a channel is stuck, restarting nullclaw.service"
            systemctl restart nullclaw.service
          fi
        '';
        path = [ config.systemd.package pkgs.gnugrep ];
      };
      systemd.timers.nullclaw-watchdog = mkIf cfg.watchdog.enable {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = cfg.watchdog.interval;
          OnUnitActiveSec = cfg.watchdog.interval;
        };
      };
    })
  ]);
}
