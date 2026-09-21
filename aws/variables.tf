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

variable "ec2_instance_type" {
  description = "Ec2 tye to use for k8s nodes"
  type        = string
  default     = "t3a.medium"
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 1

  validation {
    condition     = var.worker_count >= 0 && var.worker_count <= 5
    error_message = "worker_count must be between 0 and 5."
  }
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes (kubeadm needs >= 2 vCPU / 2 GiB)"
  type        = string
  default     = "t3a.medium"
}
