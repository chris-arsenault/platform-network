# NixOS AMI Layers

The `infrastructure/nixos/` folder contains the declarative system layers that replace the
Terraform `user_data` bootstrap scripts. The modules are designed to be composed when baking
per-role NixOS AMIs so that instances come up with all configuration files and services
already in place.

## Layout

- `modules/base.nix` – shared hardening and observability concerns:
  - disables SSH password authentication, configures chrony/auditd, and enforces the secure umask via shell policy
  - enables AppArmor, hardened kernel packages, AIDE, AWS SSM Agent, and other NixOS-native hardening options
  - renders `/etc/vector/vector.toml` with a build-scoped log stream token and a configurable CloudWatch region (default `us-east-1`)
- `modules/vector-config.nix` – helper that produces the Vector TOML from simple log descriptors.
- `wireguard.nix` – role module for the WireGuard hub. It depends on:
  - `homeLab.wireguard` options for tunnel CIDRs, peer public keys, and the Secrets Manager ARN used for the server keypair
  - the SSM parameter path where the public key is published
  - baked-in WireGuard peers and NAT rules managed by systemd units instead of shell `user_data`
- `nat.nix` – configures the standalone NAT appliance, enabling Kernel forwarding plus NixOS `networking.nat`/firewall primitives for masquerading.
- `reverse-proxy.nix` – provisions nginx virtual hosts based on the `homeLab.reverseProxy.routes` map and streams logs through Vector.

Each role module imports the base layer and exposes a small option set tailored to that host
type. When building an AMI, provide those option values alongside any additional system-wide
overrides (for example, hostname, users, or extra packages).

## Building AMIs

This directory is part of the repository flake (see `flake.nix`). The flake exposes
each module via `nixosModules`. To consume a module outside this repo you can run:

```bash
nix eval ".#nixosModules.wireguard"
```

When starting a new image configuration, clone this repository and create a lock file:

```bash
nix flake lock
```

Then author a host configuration that imports the desired module(s) from
`self.nixosModules`, for example:

```nix
{ inputs, ... }: {
  imports = [
    inputs.self.nixosModules.base
    inputs.self.nixosModules.wireguard
  ];

  homeLab = {
    resourcePrefix = "vpn";
    wireguard = {
      homeLanCidr       = "192.168.66.0/24";
      privateSubnetCidr = "10.42.20.0/24";
      secretArn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:vpn/wireguard";
      ssmPublicKeyPath  = "/vpn/server_public_key";
      homePeerPublicKey = "<NAS public key>";
    };
  };
}
```

1. Instantiate a NixOS configuration (similar to the example above) that imports the desired role modules from the flake and sets any required `homeLab` options.

2. Build the image using your preferred tooling (`nix build`, `nixos-rebuild`, or `nix run`
   wrappers such as `nixos-generators` or `nixos-anywhere`).
3. Register the resulting AMI and pass the ID into Terraform through the new variables:
   - `wireguard_ami_id`
   - `nat_ami_id`
   - `reverse_proxy_ami_id`

### Local builds

Example targets are pre-wired in the repository flake. To build AMIs locally:

```bash
# WireGuard hub AMI (output is ./result)
nix build .#wireguard-ami

# NAT instance AMI
nix build .#nat-ami

# Reverse proxy AMI
nix build .#reverse-proxy-ami
```

Each build produces a raw AMI bundle under `result/` that can be uploaded with
`aws ec2 import-image` or other preferred tooling. Update the placeholder values in
`flake.nix` (for peer keys, upstream routes, etc.) before producing production images.

With the configuration rendered by Nix, EC2 instances only require minimal post-boot actions,
and Terraform no longer needs to ship large `user_data` payloads.
