{ config, lib, pkgs, ... }:

let
  base = import ./modules/base.nix;
  renderVector = import ./modules/vector-config.nix { inherit lib; };
in {
  imports = [ base ];

  options.homeLab.nat = {
    privateSubnetCidr = lib.mkOption {
      type = lib.types.str;
      description = "CIDR routed through the NAT instance.";
    };

    externalInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Interface used for outbound internet access. Defaults to the detected primary interface.";
    };
  };

  config =
    let
      cfg = config.homeLab.nat;
      primaryInterface = config.networking.primaryInterface;
      externalIface =
        if cfg.externalInterface != null then cfg.externalInterface
        else if primaryInterface != null then primaryInterface
        else "eth0";
      region = config.homeLab.vectorRegion;
      streamToken = config.homeLab.vectorStreamTokenComputed;

      vectorConfig =
        let
          logGroup = "/aws/vpn/${config.homeLab.resourcePrefix}/nat";
        in
        renderVector {
          region = region;
          streamToken = streamToken;
          fileLogs = [ ];
          journalLogs = [
            {
              matchField = "SYSLOG_IDENTIFIER";
              matchValue = "kernel";
              logGroupName = logGroup;
              logStreamName = "kernel";
            }
            {
              matchField = "SYSLOG_IDENTIFIER";
              matchValue = "sshd";
              logGroupName = logGroup;
              logStreamName = "journal-sshd";
            }
            {
              matchField = "SYSLOG_IDENTIFIER";
              matchValue = "auditd";
              logGroupName = logGroup;
              logStreamName = "journal-audit";
            }
          ];
        };
    in {
      homeLab.vectorConfig = vectorConfig;

      networking.firewall = {
        enable = true;
        allowPing = true;
        allowForwardedTraffic = true;
      };

      networking.nat = {
        enable = true;
        enableIPv6 = false;
        externalInterface = externalIface;
        internalIPs = [ cfg.privateSubnetCidr ];
      };

      boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 1;

    };
}
