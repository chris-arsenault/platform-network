data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "root" {
  name         = var.root_domain_name
  private_zone = false
}

locals {
  prefix                 = var.prefix
  wireguard_port         = 51820
  wireguard_cidr         = "10.200.0.0/24"
  wireguard_cidr_host    = "10.200.0.1/24"
  vpc_cidr               = "10.42.0.0/16"
  public_subnet_cidr     = "10.42.10.0/24"
  public_subnet_cidr_b   = "10.42.11.0/24"
  private_subnet_cidr    = "10.42.20.0/24"
  allowed_cidrs          = ["0.0.0.0/0"]
  allowed_ipv6_cidrs     = []
  laptop_peer_public_key = trimspace(var.laptop_peer_public_key)
  ssm_public_key_path    = "/${local.prefix}/server_public_key"
  home_peer_address      = format("%s/32", cidrhost(local.wireguard_cidr, 2))
  reverse_proxy_routes = {
    "dashboards.ahara.io" = {
      address = "192.168.66.3"
      port    = 30037
    }
  }
  azs                            = slice(data.aws_availability_zones.available.names, 0, 2)
  az                             = local.azs[0]
  az_secondary                   = local.azs[1]
  cognito_auth_domain            = "auth.${var.root_domain_name}"
  reverse_proxy_hostnames        = sort(keys(local.reverse_proxy_routes))
  reverse_proxy_primary_hostname = local.reverse_proxy_hostnames[0]
  reverse_proxy_sans             = [for host in local.reverse_proxy_hostnames : host if host != local.reverse_proxy_primary_hostname]
  route53_zone_id                = data.aws_route53_zone.root.zone_id
}
