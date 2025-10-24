{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # Import qemu-vm module to provide virtualisation.diskSize option
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  # EC2-specific user configuration
  users.users.ec2-user = {
    isNormalUser = true;
    createHome = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
    initialHashedPassword = "*";
  };

  # EC2 network configuration
  networking.useDHCP = lib.mkDefault true;

  # AMI disk size (8GB)
  virtualisation.diskSize = lib.mkDefault (8 * 1024);
}
