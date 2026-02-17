# Provider Configurations

# Configure the MikroTik provider
provider "routeros" {
  hosturl  = "https://${var.router_host}"
  username = var.router_username
  password = var.router_password
  insecure = var.router_insecure
}

# Configure the Kubernetes provider to connect to your k3s cluster
provider "kubernetes" {
  config_path = var.kubeconfig_path
}
