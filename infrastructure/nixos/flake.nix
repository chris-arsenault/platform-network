{
  description = "NixOS modules for the VPN home-lab AMIs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    generators.url = "github:nix-community/nixos-generators";
  };

  outputs = { self, nixpkgs, generators, ... }: let
    system = "x86_64-linux";
    lib = nixpkgs.lib;

    # Export modules for reuse
    modules = {
      base = ./modules/base.nix;
      wireguard = ./modules/wireguard.nix;
      nat = ./modules/nat.nix;
      reverseProxy = ./modules/reverse-proxy.nix;
    };

    # Profiles for different deployment targets
    profiles = {
      aws-ec2 = ./profiles/aws-ec2.nix;
    };

    # Create a NixOS configuration for a specific host
    mkNixosConfiguration = name: roleModule: hostConfig:
      lib.nixosSystem {
        inherit system;
        modules = [
          modules.base
          profiles.aws-ec2
          roleModule
          hostConfig
          {
            networking.hostName = name;
          }
        ];
      };

    # Host configurations
    hosts = {
      wireguard = mkNixosConfiguration "wireguard" modules.wireguard ./hosts/wireguard;
      nat = mkNixosConfiguration "nat" modules.nat ./hosts/nat;
      reverseProxy = mkNixosConfiguration "reverseProxy" modules.reverseProxy ./hosts/reverseProxy;
    };
  in {
    # Export modules for external use
    nixosModules = modules // { inherit profiles; };

    # Expose full NixOS configurations
    nixosConfigurations = hosts;

    # AMI images as packages
    packages.${system} = {
      default = nixpkgs.legacyPackages.${system}.writeText "vpn-nixos-modules.txt" ''
        This flake provides NixOS modules under `.nixosModules`.
        AMI images can be built with:
          nix build .#wireguard-ami
          nix build .#nat-ami
          nix build .#reverseProxy-ami
      '';

      wireguard-ami = generators.nixosGenerate {
        inherit system;
        modules = [
          modules.base
          profiles.aws-ec2
          modules.wireguard
          ./hosts/wireguard
          { networking.hostName = "wireguard"; }
        ];
        format = "amazon";
      };

      nat-ami = generators.nixosGenerate {
        inherit system;
        modules = [
          modules.base
          profiles.aws-ec2
          modules.nat
          ./hosts/nat
          { networking.hostName = "nat"; }
        ];
        format = "amazon";
      };

      reverseProxy-ami = generators.nixosGenerate {
        inherit system;
        modules = [
          modules.base
          profiles.aws-ec2
          modules.reverseProxy
          ./hosts/reverseProxy
          { networking.hostName = "reverseProxy"; }
        ];
        format = "amazon";
      };
    };

    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;
  };
}
