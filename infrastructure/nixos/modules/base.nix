{ config, lib, pkgs, ... }:

let
  streamToken =
    if config.homeLab.vectorStreamToken != null then
      config.homeLab.vectorStreamToken
    else
      builtins.substring 0 12 (builtins.hashString "sha256" (builtins.toString config.system.build.toplevel));
in {
  options.homeLab = {
    resourcePrefix = lib.mkOption {
      type = lib.types.str;
      default = "vpn";
      description = ''
        Logical prefix used when referencing shared resources such as CloudWatch log groups.
        Override this to align with the Terraform ``resource_prefix``.
      '';
    };

    vectorConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = "Rendered Vector configuration. When null the Vector service is disabled.";
    };

    vectorRegion = lib.mkOption {
      type = lib.types.str;
      default = "us-east-1";
      description = "AWS region used when Vector ships logs to CloudWatch.";
    };

    vectorStreamToken = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Optional token appended to CloudWatch log stream names to keep them unique per AMI.
        Defaults to a hash derived from the build output.
      '';
    };

    vectorStreamTokenComputed = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "";
      description = "Derived log stream token exposed for role modules.";
    };
  };

  config = {
    system.stateVersion = lib.mkDefault "23.11";

    homeLab.vectorStreamTokenComputed = streamToken;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
        X11Forwarding = false;
      };
    };

    services.amazon-ssm-agent.enable = true;

    services.chrony.enable = true;

    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_hardened;

    boot.kernel.sysctl = {
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "kernel.kptr_restrict" = 1;
      "kernel.randomize_va_space" = 2;
    };

    environment.systemPackages = with pkgs; [
      aide
      awscli2
      coreutils
      curl
      jq
      iproute2
      vector
    ];

    environment.loginShellInit = ''
      umask 027
    '';

    systemd.coredump.enable = false;

    security.lockKernelModules = true;
    security.protectKernelImage = true;
    security.allowSimultaneousMultithreadedCpus = lib.mkDefault false;
    security.apparmor.enable = true;
    security.auditd.enable = true;
    security.sudo.execWheelOnly = true;
    security.pam.loginLimits = [
      { domain = "*"; type = "hard"; item = "core"; value = "0"; }
      { domain = "*"; type = "hard"; item = "nofile"; value = "65536"; }
      { domain = "*"; type = "soft"; item = "nofile"; value = "65536"; }
    ];

    systemd.tmpfiles.rules = [
      "d /etc/vector 0755 root root -"
      "d /var/lib/vector 0755 root root -"
    ];

    services.aide = {
      enable = true;
      config = builtins.readFile ../files/base/aide/aide.conf;
      timerConfig.OnCalendar = "daily";
    };

    systemd.services.vector = lib.mkIf (config.homeLab.vectorConfig != null) {
      description = "Vector observability pipeline";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.vector}/bin/vector --config /etc/vector/vector.toml";
        Restart = "always";
        RestartSec = 5;
        LimitNOFILE = 65536;
      };
    };

    environment.etc."vector/vector.toml" = lib.mkIf (config.homeLab.vectorConfig != null) {
      source = pkgs.writeText "vector-config.toml" config.homeLab.vectorConfig;
    };

    systemd.services.aide-initialize = {
      description = "Initialise AIDE integrity database";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.aide}/bin/aide --init";
        ExecStartPost = "${pkgs.coreutils}/bin/mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz";
      };
      wants = [ "local-fs.target" ];
      after = [ "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = "!/var/lib/aide/aide.db.gz";
    };
  };
}
