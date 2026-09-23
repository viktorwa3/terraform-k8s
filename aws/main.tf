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

# us-east-1e has no t3a.*, so pick an AZ that offers both instance types.
data "aws_ec2_instance_type_offerings" "cluster" {
  for_each      = toset([var.ec2_instance_type, var.worker_instance_type])
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [each.key]
  }
}

locals {
  cluster_az = sort(tolist(setintersection(
    [for o in data.aws_ec2_instance_type_offerings.cluster : toset(o.locations)]...
  )))[0]
}

resource "aws_subnet" "cluster_internal" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.cluster_az
  map_public_ip_on_launch = true

  tags = local.default_tags
}

resource "aws_security_group" "kubernetes" {
  name        = "kubernetes"
  description = "Allow kubernetes ports"
  vpc_id      = aws_vpc.main.id

  tags = local.default_tags
}

# All nodes share this SG: any traffic between cluster nodes.
resource "aws_vpc_security_group_ingress_rule" "cluster_internal" {
  security_group_id            = aws_security_group.kubernetes.id
  referenced_security_group_id = aws_security_group.kubernetes.id
  ip_protocol                  = "-1"
  description                  = "All traffic between cluster nodes"
}

# Without this Terraform revokes AWS's default allow-all-outbound.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.kubernetes.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound"
}

# No cloud-controller-manager, so NodePort is the cluster's entrypoint.
resource "aws_vpc_security_group_ingress_rule" "ingress_nginx" {
  for_each = { for pair in setproduct(var.web_access_cidrs, [30080, 30443]) : "${pair[0]}-${pair[1]}" => {
    cidr = pair[0]
    port = pair[1]
  } }

  security_group_id = aws_security_group.kubernetes.id
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value.cidr
  from_port         = each.value.port
  to_port           = each.value.port
  description       = "ingress-nginx NodePort"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.kubernetes.id
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0" # to be able to use public free github repo runners
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
  iam_instance_profile   = aws_iam_instance_profile.node.name

  # Hop limit 3: the IMDSv2 token reply must survive Cilium's extra hop into a pod.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 3
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    tags        = local.default_tags
  }

  user_data = file("${path.module}/cloud-config.yaml")

  # Name is the Ansible inventory hostname; Role drives its groups.
  tags = merge(local.default_tags, {
    Name = "${var.app_name}-cp-0"
    Role = "control-plane"
  })
}

resource "aws_instance" "worker" {
  count = var.worker_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.cluster_internal.id
  vpc_security_group_ids = [aws_security_group.kubernetes.id]
  key_name               = data.aws_key_pair.common_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.node.name

  # Hop limit 3: the IMDSv2 token reply must survive Cilium's extra hop into a pod.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 3
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    tags        = local.default_tags
  }

  user_data = file("${path.module}/cloud-config.yaml")

  tags = merge(local.default_tags, {
    Name = "${var.app_name}-worker-${count.index}"
    Role = "worker"
  })
}