data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_network_interface" "eni0" {
  subnet_id         = aws_subnet.public.id
  security_groups   = [aws_security_group.wireguard.id]
  source_dest_check = false
}

resource "aws_instance" "wireguard" {
  ami                  = local.ami_id
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.wireguard.name

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    WG_PORT             = local.wireguard_port
    WG_CIDR             = local.wireguard_cidr
    WG_CIDR_HOST        = local.wireguard_cidr_host
    HOME_LAN_CIDR       = var.home_lan_cidr
    HOME_PEER_PUBKEY    = var.home_peer_public_key
    LAPTOP_PEER_PUBKEY  = local.laptop_peer_public_key
    PRIVATE_SUBNET_CIDR = local.private_subnet_cidr
    SSM_PUBLIC_KEY_PATH = local.ssm_public_key_path
    AWS_REGION          = "us-east-1"
    SECRET_ID           = aws_secretsmanager_secret.wg_keys.id
  })
  disable_api_termination = false

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
    network_interface_id = aws_network_interface.eni0.id
  }

  tags = {
    Name = "${local.prefix}-wireguard-server"
  }

  volume_tags = {
    project    = local.prefix
    Name       = "${local.prefix}-wireguard-vol"
    managed_by = "terraform"
  }

  user_data_replace_on_change = true
  lifecycle { create_before_destroy = false }
}

resource "aws_eip" "wireguard" {
  domain = "vpc"

  tags = {
    Name = "${local.prefix}-wireguard-server-eip"
  }
}

resource "aws_eip_association" "wireguard" {
  allocation_id        = aws_eip.wireguard.id
  network_interface_id = aws_network_interface.eni0.id
}
