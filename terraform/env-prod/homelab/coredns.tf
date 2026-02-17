# CoreDNS DNS Server Configuration
# Terraform resources for CoreDNS on k3s cluster
# Provides DNS resolution for home lab devices with both forward and reverse DNS

# Create DNS namespace
resource "kubernetes_namespace" "dns" {
  metadata {
    name = var.dns_namespace
    labels = {
      name = var.dns_namespace
    }
  }
}

# Generate CoreDNS Corefile configuration with dynamic DNS records
locals {
  # Generate forward DNS records from the map
  forward_records = join("\n          ", [
    "# Server itself",
    "${var.server_ip} dns-server.${var.home_domain}",
    "# Home Lab DNS Records",
    join("\n          ", [
      for ip, hostname in var.dns_records :
      "${ip} ${hostname}.${var.home_domain}"
    ]),
    "fallthrough"
  ])

  # Generate reverse DNS records (last octet to hostname mapping)
  reverse_records = join("\n          ", [
    "# Server itself",
    "${split(".", var.server_ip)[3]} dns-server.${var.home_domain}",
    "# Home Lab Reverse DNS Records",
    join("\n          ", [
      for ip, hostname in var.dns_records :
      "${split(".", ip)[3]} ${hostname}.${var.home_domain}"
    ])
  ])

  # Calculate reverse DNS zone from DHCP network
  reverse_zone = join(".", reverse(split(".", split("/", var.dhcp_network)[0])))

  # CoreDNS Corefile template
  corefile = templatefile("${path.module}/coredns-corefile.tpl", {
    forward_records = local.forward_records
    reverse_records = local.reverse_records
    reverse_zone    = local.reverse_zone
    home_domain     = var.home_domain
  })
}

# CoreDNS ConfigMap containing the Corefile with dynamic DNS records
resource "kubernetes_config_map" "coredns" {
  metadata {
    name      = "coredns"
    namespace = kubernetes_namespace.dns.metadata[0].name
  }

  data = {
    "Corefile" = local.corefile
  }

  depends_on = [kubernetes_namespace.dns]
}

# ServiceAccount for CoreDNS
resource "kubernetes_service_account" "coredns" {
  metadata {
    name      = "coredns"
    namespace = kubernetes_namespace.dns.metadata[0].name
    labels = {
      "kubernetes.io/cluster-service"   = "true"
      "addonmanager.kubernetes.io/mode" = "Reconcile"
    }
  }

  depends_on = [kubernetes_namespace.dns]
}

# ClusterRole for CoreDNS
resource "kubernetes_cluster_role" "coredns" {
  metadata {
    name = "system:coredns"
    labels = {
      "kubernetes.io/bootstrapping"     = "rbac-defaults"
      "addonmanager.kubernetes.io/mode" = "Reconcile"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["endpoints", "services", "pods", "namespaces"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["list", "watch"]
  }
}

# ClusterRoleBinding for CoreDNS
resource "kubernetes_cluster_role_binding" "coredns" {
  metadata {
    name = "system:coredns"
    labels = {
      "kubernetes.io/bootstrapping"     = "rbac-defaults"
      "addonmanager.kubernetes.io/mode" = "Reconcile"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:coredns"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "coredns"
    namespace = kubernetes_namespace.dns.metadata[0].name
  }

  depends_on = [kubernetes_service_account.coredns, kubernetes_cluster_role.coredns]
}

# CoreDNS Deployment
resource "kubernetes_deployment" "coredns" {
  metadata {
    name      = "coredns"
    namespace = kubernetes_namespace.dns.metadata[0].name
    labels = {
      "k8s-app"                         = "coredns"
      "kubernetes.io/cluster-service"   = "true"
      "addonmanager.kubernetes.io/mode" = "Reconcile"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "k8s-app" = "coredns"
      }
    }

    template {
      metadata {
        labels = {
          "k8s-app" = "coredns"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.coredns.metadata[0].name

        container {
          name  = "coredns"
          image = "coredns/coredns:${var.coredns_image_version}"

          args = ["-conf", "/etc/coredns/Corefile"]

          port {
            container_port = 53
            name           = "dns"
            protocol       = "UDP"
          }

          port {
            container_port = 53
            name           = "dns-tcp"
            protocol       = "TCP"
          }

          port {
            container_port = 9153
            name           = "metrics"
            protocol       = "TCP"
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/coredns"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 60
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8181
            }
            initial_delay_seconds = 30
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 3
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "70Mi"
            }
          }
        }

        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.coredns.metadata[0].name
            items {
              key  = "Corefile"
              path = "Corefile"
            }
          }
        }

        dns_policy = "Default"
      }
    }
  }

  depends_on = [
    kubernetes_config_map.coredns,
    kubernetes_service_account.coredns,
    kubernetes_cluster_role_binding.coredns
  ]
}

# CoreDNS Service
resource "kubernetes_service" "coredns" {
  metadata {
    name      = "coredns"
    namespace = kubernetes_namespace.dns.metadata[0].name
    labels = {
      "k8s-app"                         = "coredns"
      "kubernetes.io/cluster-service"   = "true"
      "addonmanager.kubernetes.io/mode" = "Reconcile"
    }
  }

  spec {
    selector = {
      "k8s-app" = "coredns"
    }

    port {
      name        = "dns"
      port        = 53
      protocol    = "UDP"
      target_port = 53
    }

    port {
      name        = "dns-tcp"
      port        = 53
      protocol    = "TCP"
      target_port = 53
    }

    port {
      name        = "metrics"
      port        = 9153
      protocol    = "TCP"
      target_port = 9153
    }

    type             = "LoadBalancer"
    load_balancer_ip = var.server_ip
  }

  depends_on = [kubernetes_deployment.coredns]
}

# Outputs
output "dns_service_ip" {
  description = "LoadBalancer IP of the CoreDNS service"
  value       = try(kubernetes_service.coredns.status[0].load_balancer[0].ingress[0].ip, "pending")
}

output "dns_namespace" {
  description = "Namespace where DNS services are deployed"
  value       = kubernetes_namespace.dns.metadata[0].name
}
