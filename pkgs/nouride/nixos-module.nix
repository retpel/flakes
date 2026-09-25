# NixOS module: the systemd service install.sh would set up, minus the self-updater
# (the binary lives in the read-only store — bump hashes.json instead).
self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nouride;
  isRouter = (cfg.package.passthru.edition or "standard") == "router";
  # Left at the default, the daemon gets its own isolated system user. Set to an
  # existing account, it runs as that user out of their home instead.
  dedicatedUser = cfg.user == "nouride";
in
{
  options.services.nouride = {
    enable = lib.mkEnableOption "Nouride, a multi-agent AI daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.nouride;
      defaultText = lib.literalExpression "retpel.packages.\${system}.nouride";
      description = "Nouride build to run. Use the `nouride-router` package for the Router edition.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the dashboard binds to. `0.0.0.0` exposes it on the network.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18254;
      description = "Dashboard / API port.";
    };

    routerPort = lib.mkOption {
      type = lib.types.port;
      default = 18256;
      description = "Port of the in-process Nougate gateway (Router edition only; set `[nougate] port` to match).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the dashboard port (and the Nougate port for the Router edition).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "nouride";
      example = "alice";
      description = ''
        User the daemon runs as. The default creates an isolated `nouride` system user.
        Set it to an existing account to run the daemon as that user, with its state in
        their home, so `nouride status` etc. work for them from `~`. Agents then have that
        user's access to the machine.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = if dedicatedUser then "nouride" else config.users.users.${cfg.user}.group;
      defaultText = lib.literalExpression ''if user == "nouride" then "nouride" else config.users.users.''${user}.group'';
      description = "Group the daemon runs as (created when left at `nouride`).";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = if dedicatedUser then "/var/lib/nouride" else config.users.users.${cfg.user}.home;
      defaultText = lib.literalExpression ''if user == "nouride" then "/var/lib/nouride" else config.users.users.''${user}.home'';
      description = ''
        Working directory and HOME of the daemon. It holds `config.toml` (optional) and
        `.nouride/` — the database, secrets and agent packs. The `nouride` CLI finds the
        daemon through the directory it runs from, so run it from here.
      '';
    };

    environment = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      example = {
        LOG_LEVEL = "debug";
        TZ = "Asia/Jakarta";
      };
      description = "Extra environment variables for the daemon.";
    };

    environmentFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "/run/secrets/nouride.env";
      description = "File with secrets such as bot tokens (`KEY=value` lines), kept out of the store.";
    };

    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = with pkgs; [
        bash
        coreutils
        findutils
        gnugrep
        gnused
        curl
        git
      ];
      defaultText = lib.literalExpression "with pkgs; [ bash coreutils findutils gnugrep gnused curl git ]";
      description = "Packages on the daemon's PATH, i.e. the commands agents can execute.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf dedicatedUser {
      nouride = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.stateDir;
      };
    };
    users.groups = lib.mkIf (cfg.group == "nouride") { nouride = { }; };

    environment.systemPackages = [ cfg.package ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      [ cfg.port ] ++ lib.optional isRouter cfg.routerPort
    );

    systemd.tmpfiles.settings.nouride = {
      # Only for the dedicated user; an existing user's home is already set up.
      ${cfg.stateDir}.d = lib.mkIf dedicatedUser {
        inherit (cfg) user group;
        mode = "0750";
      };
      # The daemon takes the directory above .nouride/ as its install directory and
      # only offers agents the `nouride` tool when the binary sits there, as in
      # upstream's layout. `exec nouride ...` is refused in favour of that tool.
      "${cfg.stateDir}/nouride"."L+".argument = "${cfg.package}/libexec/nouride/nouride";
    };

    systemd.services.nouride = {
      description = "Nouride multi-agent AI daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      # The nouride CLI too, so agents can reach it through `exec` (and the `nouride` tool).
      path = [ cfg.package ] ++ cfg.extraPackages;

      environment = {
        HOME = cfg.stateDir;
        HOST = cfg.host;
        PORT = toString cfg.port;
        NOURIDE_SERVICE_KIND = "systemd";
      }
      // cfg.environment;

      startLimitBurst = 5;
      startLimitIntervalSec = 120;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        ExecStart = "${lib.getExe cfg.package} start";
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
        Restart = "always";
        RestartSec = 5;
        # In-flight turns are saved on SIGTERM; matches [daemon] shutdown_timeout_ms with headroom.
        TimeoutStopSec = 45;
        KillSignal = "SIGTERM";
        UMask = "0027";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "full";
        # A regular user's state lives in their home, so /home stays visible then.
        ProtectHome = dedicatedUser;
      };
    };
  };
}
