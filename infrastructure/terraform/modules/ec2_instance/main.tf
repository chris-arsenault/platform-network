locals {
  instance_tags = { Name = var.name }
  volume_tags   = { Name = "${var.name}-vol" }
  eni_tags      = { Name = "${var.name}-eni" }
  eip_tags      = { Name = "${var.name}-eip" }
}
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

resource "aws_network_interface" "this" {
  subnet_id         = var.subnet_id
  security_groups   = var.security_group_ids
  source_dest_check = false

  tags = local.eni_tags
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.micro"
  iam_instance_profile        = var.iam_instance_profile
  disable_api_termination     = false
  user_data                   = var.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
    encrypted   = true
  }

  primary_network_interface {
    network_interface_id = aws_network_interface.this.id
  }

  tags        = local.instance_tags
  volume_tags = local.volume_tags

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_eip" "this" {
  count  = var.associate_eip ? 1 : 0
  domain = "vpc"

  tags = local.eip_tags
}

resource "aws_eip_association" "this" {
  count = var.associate_eip ? 1 : 0

  allocation_id        = aws_eip.this[0].id
  network_interface_id = aws_network_interface.this.id
}
