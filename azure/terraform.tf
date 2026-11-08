terraform {

  cloud {
    organization = "test132134132432"

    workspaces {
      project = "terraform-k8s"
      name    = "azure"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }

  required_version = ">= 1.15.8"
}
