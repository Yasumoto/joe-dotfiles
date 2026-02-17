# MikroTik RouterOS Network Configuration
# Core networking: IP addresses, NAT, routing

# LAN Bridge IP Address
resource "routeros_ip_address" "lan_bridge" {
  address   = "${var.dhcp_gateway}/${split("/", var.dhcp_network)[1]}"
  interface = "lan-bridge"
  comment   = "Main LAN gateway"

  lifecycle {
    prevent_destroy = true
  }
}

# NAT Masquerade for WAN
resource "routeros_ip_firewall_nat" "masquerade_wan" {
  chain              = "srcnat"
  action             = "masquerade"
  out_interface_list = "WAN"
  comment            = "Masquerade LAN to WAN"

  lifecycle {
    prevent_destroy = true
  }
}

# Outputs
output "lan_gateway_ip" {
  description = "LAN gateway IP address"
  value       = routeros_ip_address.lan_bridge.address
}
