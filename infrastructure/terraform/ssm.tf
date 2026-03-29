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

# --- Shared ALB parameters for consuming projects ---

resource "aws_ssm_parameter" "alb_listener_arn" {
  name  = "/platform/network/alb-listener-arn"
  type  = "String"
  value = aws_lb_listener.https.arn
}

resource "aws_ssm_parameter" "alb_arn" {
  name  = "/platform/network/alb-arn"
  type  = "String"
  value = aws_lb.reverse_proxy.arn
}

resource "aws_ssm_parameter" "alb_dns_name" {
  name  = "/platform/network/alb-dns-name"
  type  = "String"
  value = aws_lb.reverse_proxy.dns_name
}

resource "aws_ssm_parameter" "alb_zone_id" {
  name  = "/platform/network/alb-zone-id"
  type  = "String"
  value = aws_lb.reverse_proxy.zone_id
}

resource "aws_ssm_parameter" "alb_security_group_id" {
  name  = "/platform/network/alb-security-group-id"
  type  = "String"
  value = aws_security_group.alb.id
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/platform/network/vpc-id"
  type  = "String"
  value = aws_vpc.this.id
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/platform/network/public-subnet-ids"
  type  = "StringList"
  value = join(",", [aws_subnet.public.id, aws_subnet.public_b.id])
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/platform/network/private-subnet-ids"
  type  = "StringList"
  value = join(",", [aws_subnet.private.id, aws_subnet.private_b.id])
}

resource "aws_ssm_parameter" "lambda_security_group_id" {
  name  = "/platform/network/lambda-security-group-id"
  type  = "String"
  value = aws_security_group.platform_lambda.id
}

resource "aws_ssm_parameter" "route53_zone_id" {
  name  = "/platform/network/route53-zone-id"
  type  = "String"
  value = local.route53_zone_id
}
