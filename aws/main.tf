provider "aws" {
  region = var.location
}

resource "aws_resourcegroups_group" "example" {
  name = "rg-${var.app_name}"
  tags = local.default_tags

  resource_query {
    type = "TAG_FILTERS_1_0"
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Application"
          Values = [var.app_name]
        },
        {
          Key    = "Environment"
          Values = [var.environment]
        }
      ]
    })
  }
}

locals {
  default_tags = {
    Application = var.app_name
    Environment = var.environment
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = local.default_tags
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = local.default_tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = local.default_tags
}

resource "aws_route_table_association" "cluster_internal" {
  subnet_id      = aws_subnet.cluster_internal.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "cluster_internal" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = local.default_tags
}

resource "aws_security_group" "kubernetes" {
  name        = "kubernetes"
  description = "Allow kubernetes ports"
  vpc_id      = aws_vpc.main.id

  tags = local.default_tags
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes" {
  count = length(var.subnet_cluster_internal_ports)

  security_group_id = aws_security_group.kubernetes.id
  ip_protocol       = "tcp"
  cidr_ipv4         = aws_subnet.cluster_internal.cidr_block
  from_port         = var.subnet_cluster_internal_ports[count.index]
  to_port           = var.subnet_cluster_internal_ports[count.index]
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each          = var.subnet_cluster_internal_allowed_ssh_ips
  security_group_id = aws_security_group.kubernetes.id
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"                         # to be able to use public free github repo runners
  from_port         = 22
  to_port           = 22
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_key_pair" "common_key" {
  key_name           = "common-ssh"
  include_public_key = true
}

resource "aws_instance" "cp_main" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.cluster_internal.id
  vpc_security_group_ids = [aws_security_group.kubernetes.id]
  key_name               = data.aws_key_pair.common_key.key_name
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    tags        = local.default_tags
  }

  user_data = file("${path.module}/cloud-config.yaml")
  tags = local.default_tags
}