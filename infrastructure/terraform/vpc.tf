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

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.this.id
  cidr_block = local.private_subnet_cidr

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

# Route from PRIVATE subnet to WG clients via the EC2 instance
resource "aws_route" "private_to_wg" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = var.home_lan_cidr
  network_interface_id   = aws_instance.wireguard.primary_network_interface_id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.prefix}-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
