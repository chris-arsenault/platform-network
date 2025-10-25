{ config, lib, pkgs, ... }:

let
  renderVector = import ./vector-config.nix { inherit lib; };
in {

  options.homeLab.wireguard = {
    port = lib.mkOption {
      type = lib.types.int;
      default = 51820;
      description = "WireGuard UDP listen port.";
    };

    cidr = lib.mkOption {
      type = lib.types.str;
      default = "10.200.0.0/24";
      description = "WireGuard interface CIDR used for peers.";
    };

    cidrHost = lib.mkOption {
      type = lib.types.str;
      default = "10.200.0.1/24";
      description = "Host IP (with prefix) assigned to the WireGuard interface.";
    };

    homeLanCidr = lib.mkOption {
      type = lib.types.str;
      description = "Home LAN CIDR reachable over the tunnel.";
    };

    privateSubnetCidr = lib.mkOption {
      type = lib.types.str;
      description = "Private subnet CIDR for VPC resources accessed via WireGuard.";
    };

    secretArn = lib.mkOption {
      type = lib.types.str;
      description = "Secrets Manager identifier storing the WireGuard keypair JSON payload.";
    };

    ssmPublicKeyPath = lib.mkOption {
      type = lib.types.str;
      description = "SSM parameter path where the server public key is published.";
    };

    homePeerPublicKey = lib.mkOption {
      type = lib.types.str;
      description = "Public key for the NAS peer.";
    };

    laptopPeerPublicKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional public key for the laptop peer.";
    };

    externalInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Primary network interface used for outbound NAT. Defaults to the detected primary interface.";
    };
  };

  config =
    let
      cfg = config.homeLab.wireguard;
      region = config.homeLab.vectorRegion;
      streamToken = config.homeLab.vectorStreamTokenComputed;
      primaryInterface = config.networking.primaryInterface or null;
      externalIface =
        if cfg.externalInterface != null then cfg.externalInterface
        else if primaryInterface != null then primaryInterface
        else "eth0";

      keySyncScript = pkgs.substituteAll {
        src = ./wireguard/wireguard-key-sync.sh;
        isExecutable = true;
        curl = "${pkgs.curl}/bin/curl";
        aws = "${pkgs.awscli2}/bin/aws";
        jq = "${pkgs.jq}/bin/jq";
        wg = "${pkgs.wireguard-tools}/bin/wg";
        mkdir = "${pkgs.coreutils}/bin/mkdir";
        chmod = "${pkgs.coreutils}/bin/chmod";
        tee = "${pkgs.coreutils}/bin/tee";
        cat = "${pkgs.coreutils}/bin/cat";
        secretArn = cfg.secretArn;
        ssmPublicKeyPath = cfg.ssmPublicKeyPath;
      };

      vectorConfig =
        let
          logGroup = "/aws/vpn/${config.homeLab.resourcePrefix}/wireguard";
        in
        renderVector {
          region = region;
          streamToken = streamToken;
          fileLogs = [ ];
          journalLogs = [
            {
              matchField = "SYSTEMD_UNIT";
              matchValue = "wg-quick@wg0.service";
              logGroupName = logGroup;
              logStreamName = "wg-quick";
            }
            {
              matchField = "SYSTEMD_UNIT";
              matchValue = "wg-healthcheck.service";
              logGroupName = logGroup;
              logStreamName = "wg-healthcheck";
            }
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

      environment.systemPackages = with pkgs; [
        socat
        wireguard-tools
      ];

      systemd.tmpfiles.rules = [
        "d /var/lib/wireguard 0700 root root -"
      ];

      networking.firewall.allowedUDPPorts = [ cfg.port ];
      networking.firewall.allowedTCPPorts = [ 31000 ];

      networking.nat = {
        enable = true;
        enableIPv6 = false;
        externalInterface = externalIface;
        internalInterfaces = [ "wg0" ];
      };

      boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 1;

      networking.wg-quick.interfaces = {
        wg0 = {
          address = [ cfg.cidrHost ];
          listenPort = cfg.port;
          privateKeyFile = "/var/lib/wireguard/server_private.key";
          peers =
            [
              {
                publicKey = cfg.homePeerPublicKey;
                allowedIPs = [
                  cfg.homeLanCidr
                  cfg.cidr
                ];
                persistentKeepalive = 25;
              }
            ]
            ++ lib.optional (cfg.laptopPeerPublicKey != null) {
              publicKey = cfg.laptopPeerPublicKey;
              allowedIPs = [
                cfg.cidr
                cfg.homeLanCidr
                cfg.privateSubnetCidr
              ];
              persistentKeepalive = 25;
            };
        };
      };

      systemd.services."wg-quick-wg0".after = lib.mkAfter [ "wireguard-key-sync.service" ];
      systemd.services."wg-quick-wg0".requires = lib.mkAfter [ "wireguard-key-sync.service" ];

      systemd.services.wireguard-key-sync = {
        description = "Synchronise WireGuard key material with AWS Secrets Manager";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        before = [ "wg-quick-wg0.service" ];
        requiredBy = [ "wg-quick-wg0.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = keySyncScript;
        };
      };

      systemd.services.wg-healthcheck = {
        description = "TCP health check listener for the WireGuard load balancer";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.socat}/bin/socat tcp-l:31000,reuseaddr,fork exec:${pkgs.coreutils}/bin/cat";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
}
