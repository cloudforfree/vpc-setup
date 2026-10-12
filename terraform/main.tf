data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  az = data.aws_availability_zones.available.names[0]
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # Must contain at least one 40-char string
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ---------- VPC ----------
resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "lab-vpc" }
}

# ---------- Subnets ----------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true
  tags                    = { Name = "lab-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = local.az
  tags              = { Name = "lab-private" }
}

# ---------- Internet Gateway ----------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "lab-igw" }
}

# ---------- Route tables ----------
# Public: local route (implicit) + default route to the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "lab-public-rt" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Private: local route only (implicit), no internet route
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "lab-private-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ---------- Security group ----------
resource "aws_security_group" "lab" {
  name        = "lab-sg"
  description = "SSH from my IP, SSH and ICMP inside the VPC"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "lab-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_me" {
  security_group_id = aws_security_group.lab.id
  cidr_ipv4         = var.allowed_ssh_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "ssh_vpc" {
  security_group_id = aws_security_group.lab.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "icmp_vpc" {
  security_group_id = aws_security_group.lab.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.lab.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- Key pair ----------
resource "aws_key_pair" "lab" {
  key_name   = "lab"
  public_key = var.ssh_public_key
}

# ---------- Instances ----------
resource "aws_instance" "public" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.lab.id]
  key_name               = aws_key_pair.lab.key_name
  tags                   = { Name = "lab-public-ec2" }
}

resource "aws_instance" "private" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.lab.id]
  key_name               = aws_key_pair.lab.key_name
  tags                   = { Name = "lab-private-ec2" }
}
