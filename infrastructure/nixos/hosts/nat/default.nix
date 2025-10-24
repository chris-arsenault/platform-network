{ config, lib, pkgs, ... }:

{
  # NAT instance configuration
  homeLab.resourcePrefix = "vpn";

  homeLab.nat = {
    privateSubnetCidr = "10.42.20.0/24";
  };
}
