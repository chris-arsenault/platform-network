locals {
  home_peer_config = templatefile("${path.module}/templates/peer_home.conf.tpl", {
    AWS_PRIVATE_CIDR = local.private_subnet_cidr
    WG_CIDR          = local.wireguard_cidr
    WG_ADDRESS       = local.home_peer_address
    ENDPOINT         = "${module.wireguard.public_ip}:${local.wireguard_port}"
    SERVER_PUBKEY    = aws_ssm_parameter.server_public_key.value
    SSM_PARAM        = aws_ssm_parameter.server_public_key.name
  })
}
