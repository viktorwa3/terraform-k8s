variable "app_name" {
  description = "Application name to use in resources naming (lowercase, hyphens)"
  type        = string
  default     = "terraform-k8s"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.app_name))
    error_message = "app_name must be lowercase letters, digits and hyphens (2-31 chars)."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "swedencentral"
}

variable "environment" {
  description = "Environment name used in tags"
  type        = string
  default     = "dev"
}

variable "vm_size" {
  description = "VM size for all nodes (kubeadm needs >= 2 vCPU / 2 GiB)"
  type        = string
  default     = "Standard_B2s"
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 0 && var.worker_count <= 5
    error_message = "worker_count must be between 0 and 5."
  }
}

variable "ingress_dns_label" {
  description = "DNS label of the load balancer public IP (<label>.<location>.cloudapp.azure.com)"
  type        = string
  default     = "tk-argocd"
}

variable "budget_amount" {
  description = "Monthly budget in USD for the resource group"
  type        = number
  default     = 150
}

variable "budget_start_date" {
  description = "First day of a month (RFC3339) when the budget starts"
  type        = string
  default     = "2026-11-01T00:00:00Z"
}

variable "secret_reader_object_ids" {
  description = "Entra user object IDs that get Key Vault Secrets User on the vault"
  type        = list(string)
  default     = ["acdabe9e-2b86-4cb7-a253-002a714ef048"]
}
