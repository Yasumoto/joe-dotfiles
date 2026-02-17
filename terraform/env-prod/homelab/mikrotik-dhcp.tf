# MikroTik RouterOS DHCP Configuration
# Terraform configuration for managing DHCP on your MikroTik CCR router

# Note: Data sources for dhcp_server and ip_pool are not supported in this provider version
# Manage resources directly instead

# IP Pool for DHCP
resource "routeros_ip_pool" "dhcp_pool" {
  name   = var.dhcp_pool_name
  ranges = var.ip_pool_ranges

  lifecycle {
    prevent_destroy = true
    # Uncomment the line below if you want to ignore changes to ranges made outside Terraform
    # ignore_changes = [ranges]
  }
}

# DHCP Server
resource "routeros_ip_dhcp_server" "dhcp_server" {
  name          = "dhcp1"
  interface     = var.dhcp_interface
  address_pool  = routeros_ip_pool.dhcp_pool.name
  lease_time    = var.lease_time
  authoritative = "yes"
  disabled      = false

  # Additional options
  always_broadcast       = false
  allow_dual_stack_queue = false
  use_radius             = "no"

  lifecycle {
    prevent_destroy = true
    # Uncomment the line below if you want to ignore changes to lease_time made outside Terraform
    # ignore_changes = [lease_time]
  }
}

# DHCP Server Network Configuration
resource "routeros_ip_dhcp_server_network" "dhcp_network" {
  address    = var.dhcp_network
  gateway    = var.dhcp_gateway
  dns_server = var.dns_servers
  domain     = var.dhcp_domain

  # Use the router itself as NTP server
  ntp_server = [var.dhcp_gateway]
}

# Static DHCP Leases (Reservations)
resource "routeros_ip_dhcp_server_lease" "static_leases" {
  for_each = var.static_leases

  mac_address = each.key
  address     = each.value.ip
  comment     = each.value.comment != "" ? "${each.value.hostname} - ${each.value.comment}" : each.value.hostname
  server      = routeros_ip_dhcp_server.dhcp_server.name
  disabled    = false
}

output "dhcp_server_name" {
  description = "Name of the DHCP server"
  value       = routeros_ip_dhcp_server.dhcp_server.name
}

output "dhcp_pool_name" {
  description = "Name of the IP pool"
  value       = routeros_ip_pool.dhcp_pool.name
}

output "dhcp_network" {
  description = "DHCP network configuration"
  value       = routeros_ip_dhcp_server_network.dhcp_network.address
}

output "dns_servers_advertised" {
  description = "DNS servers advertised to DHCP clients"
  value       = routeros_ip_dhcp_server_network.dhcp_network.dns_server
}
