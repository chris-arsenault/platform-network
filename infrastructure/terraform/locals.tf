data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  prefix                 = "vpn"
  wireguard_port         = 51820
  wireguard_cidr         = "10.200.0.0/24"
  wireguard_cidr_host    = "10.200.0.1/24"
  vpc_cidr               = "10.42.0.0/16"
  public_subnet_cidr     = "10.42.10.0/24"
  private_subnet_cidr    = "10.42.20.0/24"
  allowed_cidrs          = ["0.0.0.0/0"]
  allowed_ipv6_cidrs     = []
  laptop_peer_public_key = trimspace(var.laptop_peer_public_key)
  ssm_public_key_path    = "/${local.prefix}/server_public_key"
  home_peer_address      = format("%s/32", cidrhost(local.wireguard_cidr, 2))

  ami_id = data.aws_ssm_parameter.al2023_ami.value
  az     = data.aws_availability_zones.available.names[0]
}
