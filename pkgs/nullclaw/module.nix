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
    })
  ]);
}
