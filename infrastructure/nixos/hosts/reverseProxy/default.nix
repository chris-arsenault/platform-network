{ config, lib, pkgs, ... }:

{
  # Reverse proxy configuration
  homeLab.resourcePrefix = "vpn";

  homeLab.reverseProxy.routes = {
    "example.internal" = {
      address = "192.168.66.3";
      port = 3000;
    };
  };
}
