resource "aws_iam_role" "reverse_proxy" {
  name_prefix        = "${local.prefix}-proxy-"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_instance_profile" "reverse_proxy" {
  name_prefix = "${local.prefix}-proxy-"
  role        = aws_iam_role.reverse_proxy.name
}

resource "aws_iam_role_policy_attachment" "reverse_proxy_ssm" {
  role       = aws_iam_role.reverse_proxy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

module "reverse_proxy" {
  source = "./modules/ec2_instance"

  name                 = "${local.prefix}-reverse-proxy"
  iam_instance_profile = aws_iam_instance_profile.reverse_proxy.name
  subnet_id            = aws_subnet.private.id
  security_group_ids   = [aws_security_group.reverse_proxy.id]

  user_data = templatefile("${path.module}/templates/common_user_data.sh.tpl", {
    EXTRA_SNIPPET = templatefile("${path.module}/templates/reverse_proxy_user_data.sh.tpl", {
      ROUTES = local.reverse_proxy_routes
    })
    FILE_LOGS_JSON = jsonencode([
      {
        file_path                = "/var/log/nginx/*_access.log"
        log_group_name           = aws_cloudwatch_log_group.reverse_proxy.name
        log_stream_name          = "{instance_id}/nginx-access"
        timestamp_format         = "%d/%b/%Y:%H:%M:%S %z"
        multi_line_start_pattern = "^[0-9]{2}/[A-Za-z]{3}/[0-9]{4}:"
      },
      {
        file_path                = "/var/log/nginx/*_error.log"
        log_group_name           = aws_cloudwatch_log_group.reverse_proxy.name
        log_stream_name          = "{instance_id}/nginx-error"
        timestamp_format         = "%Y/%m/%d %H:%M:%S"
        multi_line_start_pattern = "^[0-9]{4}/[0-9]{2}/[0-9]{2}"
      }
    ])
    JOURNAL_LOGS_JSON = jsonencode([
      {
        journal         = "SYSLOG_IDENTIFIER=nginx"
        log_group_name  = aws_cloudwatch_log_group.reverse_proxy.name
        log_stream_name = "{instance_id}/journal-nginx"
      },
      {
        journal         = "SYSLOG_IDENTIFIER=sshd"
        log_group_name  = aws_cloudwatch_log_group.reverse_proxy.name
        log_stream_name = "{instance_id}/journal-sshd"
      },
      {
        journal         = "SYSLOG_IDENTIFIER=auditd"
        log_group_name  = aws_cloudwatch_log_group.reverse_proxy.name
        log_stream_name = "{instance_id}/journal-audit"
      }
    ])
  })
}
