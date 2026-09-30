self:
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services."1mcp";
  home = config.users.users.${cfg.user}.home;
in {
  options.services."1mcp" = {
    enable = mkEnableOption "the 1MCP runtime (aggregates MCP servers behind one HTTP endpoint)";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}."1mcp";
      defaultText = literalExpression ''retpel.packages.''${pkgs.stdenv.hostPlatform.system}."1mcp"'';
      description = "1MCP package to run.";
    };
    user = mkOption {
      type = types.str;
      example = "alice";
      description = ''
        User the runtime and the MCP servers it starts run as. They get this
        user's PATH, so `npx`/`uvx`-style servers work.
      '';
    };
    configDir = mkOption {
      type = types.str;
      default = "${home}/.config/1mcp";
      defaultText = literalExpression ''"''${config.users.users.<user>.home}/.config/1mcp"'';
      description = ''
        1MCP config directory. `mcp.json` in it lists the MCP servers; it is
        created empty on first start and never overwritten, so it can be
        edited in place (or symlinked to a repo).
      '';
    };
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen on. Keep it on loopback and put a TLS proxy in front.";
    };
    port = mkOption {
      type = types.port;
      default = 3050;
      description = "HTTP port.";
    };
    externalUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://host.example:3050";
      description = "Public base URL, used for OAuth callbacks and advertised URLs.";
    };
    enableAuth = mkOption {
      type = types.bool;
      default = true;
      description = "Require OAuth 2.1 bearer tokens on /mcp (`--enable-auth`).";
    };
    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = "${cfg.configDir}/.env";
      defaultText = literalExpression ''"''${configDir}/.env"'';
      description = ''
        Optional KEY=value file loaded into the environment, e.g. API keys the
        MCP servers need. Skipped when missing.
      '';
    };
    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--enable-config-reload" "--enable-async-loading" ];
      description = "Extra `1mcp serve` arguments.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services."1mcp" = {
      description = "1MCP runtime";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        "/run/wrappers"
        "/etc/profiles/per-user/${cfg.user}"
        "/run/current-system/sw"
      ];
      environment.HOME = home;
      preStart = ''
        mkdir -p "${cfg.configDir}"
        [ -e "${cfg.configDir}/mcp.json" ] || echo '{ "mcpServers": {} }' > "${cfg.configDir}/mcp.json"
      '';
      serviceConfig = {
        User = cfg.user;
        Group = config.users.users.${cfg.user}.group;
        WorkingDirectory = home;
        ExecStart = escapeShellArgs (
          [
            "${cfg.package}/bin/1mcp"
            "serve"
            "--config-dir"
            cfg.configDir
            "--config"
            "${cfg.configDir}/mcp.json"
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
          ]
          ++ optionals (cfg.externalUrl != null) [ "--external-url" cfg.externalUrl ]
          ++ optional cfg.enableAuth "--enable-auth"
          ++ cfg.extraArgs
        );
        EnvironmentFile = optional (cfg.environmentFile != null) "-${cfg.environmentFile}";
        Restart = "always";
        RestartSec = 3;
      };
    };
  };
}
