# MikroTik RouterOS Firewall Configuration
# Firewall filter rules and interface lists

# Interface Lists
resource "routeros_interface_list" "lan" {
  name    = "LAN"
  comment = "LAN interfaces"
}

resource "routeros_interface_list" "wan" {
  name    = "WAN"
  comment = "WAN interfaces"
}

# Interface List Members - LAN
resource "routeros_interface_list_member" "lan_bridge" {
  list      = routeros_interface_list.lan.name
  interface = "lan-bridge"
}

resource "routeros_interface_list_member" "lan_sfp3" {
  list      = routeros_interface_list.lan.name
  interface = "sfp-sfpplus3"
}

resource "routeros_interface_list_member" "lan_ether1" {
  list      = routeros_interface_list.lan.name
  interface = "ether1"
}

# Interface List Members - WAN
resource "routeros_interface_list_member" "wan_sfp2" {
  list      = routeros_interface_list.wan.name
  interface = "sfp-sfpplus2"
}

# Firewall Filter Rules - Input Chain
resource "routeros_ip_firewall_filter" "input_established" {
  chain            = "input"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "Accept established/related/untracked connections"
}

resource "routeros_ip_firewall_filter" "input_invalid" {
  chain            = "input"
  action           = "drop"
  connection_state = "invalid"
  comment          = "Drop invalid connections"
}

resource "routeros_ip_firewall_filter" "input_icmp" {
  chain    = "input"
  action   = "accept"
  protocol = "icmp"
  comment  = "Accept ICMP"
}

resource "routeros_ip_firewall_filter" "input_lan" {
  chain             = "input"
  action            = "accept"
  in_interface_list = routeros_interface_list.lan.name
  comment           = "Accept from LAN"
}

resource "routeros_ip_firewall_filter" "input_drop_all" {
  chain   = "input"
  action  = "drop"
  comment = "Drop all other input"
}

# Firewall Filter Rules - Forward Chain
resource "routeros_ip_firewall_filter" "forward_invalid" {
  chain            = "forward"
  action           = "drop"
  connection_state = "invalid"
  comment          = "Drop invalid forwarded connections"
}

resource "routeros_ip_firewall_filter" "forward_lan_to_wan" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.lan.name
  out_interface_list = routeros_interface_list.wan.name
  comment            = "Accept LAN to WAN"
}

resource "routeros_ip_firewall_filter" "forward_established" {
  chain            = "forward"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "Accept established/related/untracked forwarded"
}

resource "routeros_ip_firewall_filter" "forward_drop_all" {
  chain   = "forward"
  action  = "drop"
  comment = "Drop all other forward"
}

# Outputs
output "lan_interfaces" {
  description = "LAN interface list name"
  value       = routeros_interface_list.lan.name
}

output "wan_interfaces" {
  description = "WAN interface list name"
  value       = routeros_interface_list.wan.name
}
