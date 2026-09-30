self:
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.littlesnitch;
in {
  options.services.littlesnitch = {
    enable = mkEnableOption "the Little Snitch for Linux network monitor daemon";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.littlesnitch;
      defaultText = literalExpression "retpel.packages.\${pkgs.stdenv.hostPlatform.system}.littlesnitch";
      description = "Little Snitch package to run.";
    };
  };

  config = mkIf cfg.enable {
    # The `littlesnitch` CLI talks to the running daemon.
    environment.systemPackages = [ cfg.package ];

    # Upstream's usr/lib/systemd/system/littlesnitch.service, ExecStart pointed
    # into the store. Its AssertCapability= lines are left out: the capability
    # bounding set below is what the daemon gets. State, rules and web UI
    # overrides live in /var/lib/littlesnitch (the daemon creates it).
    systemd.services.littlesnitch = {
      description = "Little Snitch network monitor daemon";
      wantedBy = [ "multi-user.target" ];
      # Start before networking so the eBPF hooks see every process.
      wants = [ "network-pre.target" ];
      before = [ "network-pre.target" ];
      after = [ "sysinit.target" ];
      serviceConfig = {
        Type = "notify";
        ExecStart = "${cfg.package}/bin/littlesnitch --daemon --use-cap-sys-admin";
        Restart = "on-failure";
        RestartSec = "5s";
        CapabilityBoundingSet = "CAP_BPF CAP_DAC_READ_SEARCH CAP_NET_BIND_SERVICE CAP_PERFMON CAP_SETPCAP CAP_SYS_ADMIN CAP_SYS_RESOURCE CAP_SETUID CAP_SETGID";
        MemoryDenyWriteExecute = "yes";
        NoNewPrivileges = "yes";
        PrivateDevices = "yes";
        ProtectClock = "yes";
        ProtectControlGroups = "yes";
        ProtectKernelLogs = "yes";
        ProtectKernelModules = "yes";
        ProtectProc = "noaccess";
        ProtectSystem = "full";
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        StandardOutput = "null";
        StandardError = "journal";
      };
    };
  };
}
