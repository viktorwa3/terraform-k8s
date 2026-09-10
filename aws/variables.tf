variable "app_name" {
  description = "Application name to use in resources naming"
  type        = string
}

variable "location" {
  description = "Location for aws resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "App lciation envrionment to use in resource naming"
  type        = string
  default     = "dev"
}

variable "subnet_cluster_internal_ports" {
  description = "Ports to be opened inside the cluster private subnet"
  type        = list(number)
  default     = [6443, 2379, 2380, 10250, 10257, 10259, 9100]
}

variable "subnet_cluster_internal_allowed_ssh_ips" {
  description = "Ports to be opened inside the cluster private subnet"
  type        = set(string)
  default     = ["46.255.20.10/32"]
}

variable "ec2_instance_type" {
  description = "Ec2 tye to use for k8s nodes"
  type        = string
  default     = "t3a.medium"
}