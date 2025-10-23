resource "aws_security_group" "nat" {
  name        = "${local.prefix}-nat-sg"
  description = "Allows private subnet instances to reach the NAT instance"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow traffic from within the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = [
      "::/0"
    ]
  }

  tags = {
    Name = "${local.prefix}-nat-sg"
  }
}

module "nat" {
  source = "./modules/ec2_instance"

  name                 = "${local.prefix}-nat"
  iam_instance_profile = null
  subnet_id            = aws_subnet.public.id
  security_group_ids   = [aws_security_group.nat.id]
  associate_eip        = true
  instance_type        = "t3.nano"

  user_data = templatefile("${path.module}/templates/common_user_data.sh.tpl", {
    EXTRA_SNIPPET = templatefile("${path.module}/templates/nat_instance_user_data.sh.tpl", {
      PRIVATE_SUBNET_CIDR = local.private_subnet_cidr
    })
    HARDENING_SCRIPT        = local.hardening_script
    VECTOR_REPO_CONFIG      = local.vector_repo_config
    VECTOR_SERVICE_OVERRIDE = local.vector_service_override
    VECTOR_CONFIG = templatefile("${path.module}/templates/vector_config.toml.tpl", {
      file_logs = []
      journal_logs = [
        {
          journal         = "SYSLOG_IDENTIFIER=kernel"
          log_group_name  = aws_cloudwatch_log_group.nat.name
          log_stream_name = "{instance_id}/kernel"
        },
        {
          journal         = "SYSLOG_IDENTIFIER=sshd"
          log_group_name  = aws_cloudwatch_log_group.nat.name
          log_stream_name = "{instance_id}/journal-sshd"
        },
        {
          journal         = "SYSLOG_IDENTIFIER=auditd"
          log_group_name  = aws_cloudwatch_log_group.nat.name
          log_stream_name = "{instance_id}/journal-audit"
        }
      ]
    })
  })
}
