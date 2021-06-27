terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  backend "s3" {
    bucket = "bjoli-joe-terraform-state"
    key    = "main"
    region = "us-west-2"
  }

  required_version = ">= 0.14.11"
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

