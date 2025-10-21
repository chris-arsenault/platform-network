locals {
  home_peer_config = templatefile("${path.module}/templates/peer_home.conf.tpl", {
    HOME_LAN_CIDR = var.home_lan_cidr
    WG_CIDR       = local.wireguard_cidr
    WG_ADDRESS    = local.home_peer_address
    ENDPOINT      = "${module.wireguard.public_ip}:${local.wireguard_port}"
    SERVER_PUBKEY = aws_ssm_parameter.server_public_key.value
    SSM_PARAM     = aws_ssm_parameter.server_public_key.name
  })
}
