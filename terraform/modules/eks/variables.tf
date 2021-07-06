locals {
    tags = {
        environment = var.environment
        project = var.project
    }
}

#TODO(joe): Pull from aws provider somehow instead?
variable "region" {
    type = string
    default = "us-west-2"
}

variable "environment" {
    type = string
    default = "dev"
}

variable "project" {
    type = string
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
    type = string
    default = "10.31.0.0/24"
}
