{
  description = "NixOS modules for the VPN home-lab AMIs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "aarch64-linux" ];

    modules = {
      base = import ./modules/base.nix;
      vectorConfig = import ./modules/vector-config.nix;
      wireguard = import ./wireguard.nix;
      nat = import ./nat.nix;
      reverseProxy = import ./reverse-proxy.nix;
    };

    mkFormatter = system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      pkgs.alejandra;
  in {
    nixosModules = modules;

    lib = {
      nixosModules = modules;
    };

    formatter =
      builtins.listToAttrs (map (system: {
        name = system;
        value = mkFormatter system;
      }) systems);
  };
}

