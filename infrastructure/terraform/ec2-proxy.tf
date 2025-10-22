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

  user_data = templatefile("${path.module}/templates/reverse_proxy_user_data.sh.tpl", {
    ROUTES = local.reverse_proxy_routes
  })

  depends_on = [aws_nat_gateway.this]
}
