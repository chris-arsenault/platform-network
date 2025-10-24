resource "aws_iam_role" "wireguard" {
  name_prefix        = "${local.prefix}-"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_instance_profile" "wireguard" {
  name_prefix = "${local.prefix}-"
  role        = aws_iam_role.wireguard.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.wireguard.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "wireguard_limited_perms" {
  statement {
    sid = "ManageNamespacedSsmParameters"
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource"
    ]
    resources = ["arn:aws:ssm:*:*:parameter/${local.prefix}/*"]
  }

  statement {
    sid = "RWWireGuardKeys"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:PutSecretValue"
    ]
    resources = [aws_secretsmanager_secret.wg_keys.arn]
  }
}

resource "aws_iam_role_policy" "inline_modules" {
  role   = aws_iam_role.wireguard.id
  name   = "${local.prefix}-ssm-policy"
  policy = data.aws_iam_policy_document.wireguard_limited_perms.json
}


module "wireguard" {
  source = "./modules/ec2_instance"

  name                 = "${local.prefix}-wireguard-server"
  ami_id               = var.wireguard_ami_id
  iam_instance_profile = aws_iam_instance_profile.wireguard.name
  subnet_id            = aws_subnet.private.id
  security_group_ids   = [aws_security_group.wireguard.id]
}
