terraform {

  cloud {
    organization = "test132134132432"

    workspaces {
      project = "terraform-k8s"
      name    = "light"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.15.8"
}