resource "aws_vpc" "this" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.prefix}-vgw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.prefix}-public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidr_b
  availability_zone       = local.az_secondary
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.prefix}-public-b"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidr
  availability_zone = local.az

  tags = {
    Name = "${local.prefix}-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "wireguard" {
  name        = "${local.prefix}-sg"
  description = "WireGuard access controls"
  vpc_id      = aws_vpc.this.id

  ingress {
    description      = "WireGuard UDP ingress"
    from_port        = local.wireguard_port
    to_port          = local.wireguard_port
    protocol         = "udp"
    cidr_blocks      = local.allowed_cidrs
    ipv6_cidr_blocks = local.allowed_ipv6_cidrs
  }

  ingress {
    description     = "Allow TCP from reverse proxy"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.reverse_proxy.id]
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
    Name = "${local.prefix}-sg"
  }
}

resource "aws_security_group" "alb" {
  name        = "${local.prefix}-alb-sg"
  description = "Public ALB access controls"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = "${local.prefix}-alb-sg"
  }
}

resource "aws_security_group" "reverse_proxy" {
  name        = "${local.prefix}-proxy-sg"
  description = "Allows ALB traffic to reach reverse proxy"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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
    Name = "${local.prefix}-proxy-sg"
  }
}

# Route from PRIVATE subnet to WG clients via the EC2 instance
resource "aws_route" "private_to_wg_via_lan" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = var.home_lan_cidr
  network_interface_id   = module.wireguard.primary_network_interface_id
}

resource "aws_route" "private_to_wg_via_wg" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = local.wireguard_cidr
  network_interface_id   = module.wireguard.primary_network_interface_id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "${local.prefix}-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.this]

  tags = {
    Name = "${local.prefix}-nat"
  }
}
