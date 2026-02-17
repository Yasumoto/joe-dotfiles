# Home Lab Infrastructure Configuration
# Terraform configuration for managing home lab DNS and network infrastructure

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    routeros = {
      source  = "terraform-routeros/routeros"
      version = "~> 1.99.0"
    }
  }

  # TODO(joe): Configure remote state backend for redundancy (S3, Terraform Cloud, etc.)
  backend "local" {
    path = "terraform.tfstate"
  }
}
