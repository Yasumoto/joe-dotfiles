# Home Lab Environment Variables
# Override defaults here for your specific home lab setup

# Kubernetes Configuration
variable "kubeconfig_path" {
  description = "Path to kubeconfig file for Kubernetes cluster access"
  type        = string
  default     = "../../../kubeconfig"

  validation {
    condition     = length(var.kubeconfig_path) > 0
    error_message = "Kubeconfig path cannot be empty."
  }
}

# DNS Configuration
variable "dns_namespace" {
  description = "Namespace for DNS services"
  type        = string
  default     = "dns"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.dns_namespace))
    error_message = "DNS namespace must be a valid Kubernetes namespace name (lowercase alphanumeric with hyphens)."
  }
}

variable "server_ip" {
  description = "IP address of the DNS server"
  type        = string
}

variable "home_domain" {
  description = "Domain suffix for home lab devices"
  type        = string
  default     = "home"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$", var.home_domain))
    error_message = "Home domain must be a valid domain name segment."
  }
}

variable "coredns_image_version" {
  description = "CoreDNS container image version"
  type        = string
  default     = "1.11.3"
}

variable "dns_records" {
  description = "Map of IP addresses to hostnames for DNS records"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for ip, hostname in var.dns_records :
      can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", ip)) &&
      can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$", hostname))
    ])
    error_message = "All DNS records must have valid IPv4 addresses as keys and valid hostnames as values."
  }
}

# MikroTik RouterOS DHCP Configuration
variable "router_host" {
  description = "MikroTik router hostname or IP address"
  type        = string
}

variable "router_username" {
  description = "MikroTik router admin username"
  type        = string
  default     = "admin"
}

variable "router_password" {
  description = "MikroTik router admin password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.router_password) > 0
    error_message = "Router password cannot be empty."
  }
}

variable "router_insecure" {
  description = "Skip TLS certificate verification (set to false in production)"
  type        = bool
  default     = false
}

variable "dhcp_interface" {
  description = "Interface where DHCP server runs (e.g., bridge-local, ether1)"
  type        = string
  default     = "bridge-local"
}

variable "dhcp_network" {
  description = "DHCP network CIDR"
  type        = string
}

variable "dhcp_gateway" {
  description = "Default gateway IP"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers to advertise via DHCP (your DNS server first)"
  type        = list(string)
}

variable "dhcp_domain" {
  description = "Domain name for DHCP clients"
  type        = string
  default     = "home"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$", var.dhcp_domain))
    error_message = "DHCP domain must be a valid domain name segment."
  }
}

variable "lease_time" {
  description = "DHCP lease time"
  type        = string
  default     = "1d"

  validation {
    condition     = can(regex("^[0-9]+[smhd]$", var.lease_time))
    error_message = "Lease time must be in format like '1d', '2h', '30m', '300s'."
  }
}

variable "dhcp_pool_name" {
  description = "Name of the IP pool for DHCP"
  type        = string
  default     = "home-pool"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.dhcp_pool_name))
    error_message = "DHCP pool name must contain only alphanumeric characters, underscores, and hyphens."
  }
}

variable "ip_pool_ranges" {
  description = "IP address ranges for the DHCP pool"
  type        = list(string)
}

variable "static_leases" {
  description = "Map of MAC addresses to static IP assignments"
  type = map(object({
    ip       = string
    hostname = string
    comment  = optional(string, "")
  }))
  default = {}

  validation {
    condition = alltrue([
      for mac, config in var.static_leases :
      can(regex("^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$", mac)) &&
      can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", config.ip)) &&
      can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$", config.hostname))
    ])
    error_message = "All static leases must have valid MAC addresses as keys, and valid IP addresses and hostnames in the configuration."
  }
}
