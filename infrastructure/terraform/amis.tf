locals {
  ami_ssm_prefix = "/${var.prefix}/amis"
}

data "aws_ssm_parameters_by_path" "amis" {
  path            = local.ami_ssm_prefix
  recursive       = false
  with_decryption = false
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_parameter_values = zipmap(
    [
      for name in data.aws_ssm_parameters_by_path.amis.names :
      replace(name, "${local.ami_ssm_prefix}/", "")
    ],
    [
      for value in data.aws_ssm_parameters_by_path.amis.values :
      trimspace(value)
    ]
  )

  ami_default_id = data.aws_ami.amazon_linux_2023.id

  ami_ids = {
    wireguard     = lookup(local.ami_parameter_values, "wireguard", local.ami_default_id)
    nat           = lookup(local.ami_parameter_values, "nat", local.ami_default_id)
    reverse_proxy = lookup(local.ami_parameter_values, "reverse-proxy", local.ami_default_id)
  }
}
