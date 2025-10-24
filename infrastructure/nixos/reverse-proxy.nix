{ config, lib, pkgs, ... }:

let
  base = import ./modules/base.nix;
  renderVector = import ./modules/vector-config.nix { inherit lib; };
in {
  imports = [ base ];

  options.homeLab.reverseProxy = {
    routes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options = {
          address = lib.mkOption {
            type = lib.types.str;
            description = "Upstream IPv4 address.";
          };
          port = lib.mkOption {
            type = lib.types.int;
            description = "Upstream port.";
          };
        };
      }));
      default = {};
      description = "Map of hostnames to upstream targets served by the reverse proxy.";
    };
  };

  config =
    let
      cfg = config.homeLab.reverseProxy;
      logGroup = "/aws/vpn/${config.homeLab.resourcePrefix}/reverse-proxy";
      region = config.homeLab.vectorRegion;
      streamToken = config.homeLab.vectorStreamTokenComputed;

      vectorConfig = renderVector {
        region = region;
        streamToken = streamToken;
        fileLogs = [
          {
            filePath = "/var/log/nginx/*_access.log";
            logGroupName = logGroup;
            logStreamName = "nginx-access";
          }
          {
            filePath = "/var/log/nginx/*_error.log";
            logGroupName = logGroup;
            logStreamName = "nginx-error";
          }
        ];
        journalLogs = [
          {
            matchField = "SYSLOG_IDENTIFIER";
            matchValue = "nginx";
            logGroupName = logGroup;
            logStreamName = "journal-nginx";
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

      upstreamHosts =
        lib.mapAttrs
          (host: target: {
            forceSSL = false;
            locations."/" = {
              proxyPass = "http://${target.address}:${toString target.port}";
              extraConfig = ''
                proxy_http_version 1.1;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header Connection "";
              '';
            };
            accessLog = "/var/log/nginx/${host}_access.log";
            errorLog = "/var/log/nginx/${host}_error.log warn";
          })
          cfg.routes;
    in {
      homeLab.vectorConfig = vectorConfig;

      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        virtualHosts = upstreamHosts;
      };
    };
}
