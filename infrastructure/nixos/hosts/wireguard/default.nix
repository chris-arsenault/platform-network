{ config, lib, pkgs, ... }:

{
  # WireGuard server configuration
  homeLab.resourcePrefix = "vpn";

  homeLab.wireguard = {
    homeLanCidr = "192.168.66.0/24";
    privateSubnetCidr = "10.42.20.0/24";
    secretArn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:vpn/wireguard-placeholder";
    ssmPublicKeyPath = "/vpn/server_public_key";
    homePeerPublicKey = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    laptopPeerPublicKey = null;
  };
}
