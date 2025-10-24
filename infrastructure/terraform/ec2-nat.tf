resource "aws_iam_role" "nat" {
  name_prefix        = "${local.prefix}-nat-"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_instance_profile" "nat" {
  name_prefix = "${local.prefix}-nat-"
  role        = aws_iam_role.nat.name
}

resource "aws_iam_role_policy_attachment" "nat_ssm" {
  role       = aws_iam_role.nat.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

module "nat" {
  source = "./modules/ec2_instance"

  name                 = "${local.prefix}-nat"
  ami_id               = trimspace(data.aws_ssm_parameter.ami_nat.value)
  iam_instance_profile = aws_iam_instance_profile.nat.name
  subnet_id            = aws_subnet.public.id
  security_group_ids   = [aws_security_group.nat.id]
  associate_eip        = true
  instance_type        = "t3.nano"
}
