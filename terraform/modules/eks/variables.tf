locals {
  tags = {
    environment = var.environment
    project     = var.project
  }
}

#TODO(joe): Pull from aws provider somehow instead?
variable "region" {
  type    = string
  default = "us-west-2"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "scratchpad"
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

# Where do we need to "build" this from to make sure we don't duplicate this address space?
variable "cluster_service_ipv4_cidr" {
  type    = string
  default = "10.31.0.0/24"
}

# This is an escape hatch for the occasional 🐔️ chicken-and-egg
# problem of not being able to connect to a cluster to modify the
# config_map. If you're having connectivity problems to localhost
# during a terraform plan/apply, set this to false.
variable "manage_aws_auth" {
  type    = bool
  default = true
}
