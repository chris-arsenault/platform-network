resource "aws_ssm_parameter" "server_public_key" {
  name  = local.ssm_public_key_path
  type  = "String"
  value = "PENDING"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "home_peer_conf" {
  name  = "/${local.prefix}/home_peer_conf"
  type  = "String"
  value = local.home_peer_config
}