locals {
  ami_ssm_prefix = "/${var.prefix}/amis"
}

data "aws_ssm_parameter" "ami_wireguard" {
  name = "${local.ami_ssm_prefix}/wireguard"
}

data "aws_ssm_parameter" "ami_nat" {
  name = "${local.ami_ssm_prefix}/nat"
}

data "aws_ssm_parameter" "ami_reverse_proxy" {
  name = "${local.ami_ssm_prefix}/reverse-proxy"
}
