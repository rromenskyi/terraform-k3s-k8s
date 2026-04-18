resource "random_password" "grafana" {
  for_each   = var.enable_monitoring ? toset(["enabled"]) : toset([])
  depends_on = [null_resource.k3s_install]

  length  = 16
  special = false
}

resource "helm_release" "monitoring" {
  for_each   = var.enable_monitoring ? toset(["enabled"]) : toset([])
  depends_on = [null_resource.k3s_install]

  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "70.0.0"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.adminPassword"
    value = random_password.grafana["enabled"].result
  }

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  # Grafana's chart-side ingress is left disabled on purpose. The Ingress
  # exposing grafana.localhost is managed below as `kubernetes_ingress_v1.grafana`,
  # which carries the Traefik-specific router annotations the chart would not.

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "200m"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "512Mi"
  }

  values = [
    yamlencode({
      commonLabels = local.common_labels
      grafana = {
        sidecar = {
          dashboards = {
            enabled = true
          }
        }
      }
    })
  ]
}

resource "kubernetes_ingress_v1" "grafana" {
  for_each   = var.enable_monitoring ? toset(["enabled"]) : toset([])
  depends_on = [helm_release.monitoring]

  metadata {
    name      = "grafana"
    namespace = "monitoring"
    labels    = local.common_labels
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls"         = "true"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "grafana.${var.base_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
