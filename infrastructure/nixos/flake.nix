{
  description = "NixOS modules for the VPN home-lab AMIs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" ];
    lib = nixpkgs.lib;

    forSystems = f: lib.genAttrs systems f;

    modules = {
      base = import ./modules/base.nix;
      vectorConfig = import ./modules/vector-config.nix;
      wireguard = import ./wireguard.nix;
      nat = import ./nat.nix;
      reverseProxy = import ./reverse-proxy.nix;
    };

    mkAmi = name: extraConfig:
      lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/amazon-image.nix"
          modules.base
          modules.${name}
          ({ pkgs, ... }: {
            networking.hostName = "${name}";
            users.users.ec2-user = {
              isNormalUser = true;
              createHome = true;
              uid = 1000;
              extraGroups = [ "wheel" ];
              shell = pkgs.bashInteractive;
              initialHashedPassword = "*";
            };
          })
          extraConfig
        ];
      };

    wireguardConfig = mkAmi "wireguard" {
      homeLab = {
        resourcePrefix = "vpn";
        wireguard = {
          homeLanCidr = "192.168.66.0/24";
          privateSubnetCidr = "10.42.20.0/24";
          secretArn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:vpn/wireguard-placeholder";
          ssmPublicKeyPath = "/vpn/server_public_key";
          homePeerPublicKey = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          laptopPeerPublicKey = null;
        };
      };
    };

    natConfig = mkAmi "nat" {
      homeLab = {
        resourcePrefix = "vpn";
        nat.privateSubnetCidr = "10.42.20.0/24";
      };
    };

    reverseProxyConfig = mkAmi "reverseProxy" {
      homeLab = {
        resourcePrefix = "vpn";
        reverseProxy.routes = {
          "example.internal" = {
            address = "192.168.66.3";
            port = 3000;
          };
        };
      };
    };
  in {
    nixosModules = modules;
    lib.nixosModules = modules;

    nixosConfigurations = {
      wireguard = wireguardConfig;
      nat = natConfig;
      reverseProxy = reverseProxyConfig;
    };

    packages = forSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        default = pkgs.writeText "vpn-nixos-modules.txt" ''
          This flake provides NixOS modules under `.nixosModules`.
          See `README.md` for build instructions.
        '';
        wireguard-ami = self.nixosConfigurations.wireguard.config.system.build.amazonImage;
        nat-ami = self.nixosConfigurations.nat.config.system.build.amazonImage;
        reverse-proxy-ami = self.nixosConfigurations.reverseProxy.config.system.build.amazonImage;
      });

    formatter = forSystems (system:
      let pkgs = import nixpkgs { inherit system; };
      in pkgs.alejandra);
  };
}
