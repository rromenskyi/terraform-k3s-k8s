resource "helm_release" "traefik" {
  for_each   = var.enable_traefik ? toset(["enabled"]) : toset([])
  depends_on = [null_resource.k3s_install]

  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.traefik_version
  namespace        = "traefik"
  create_namespace = true

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "ports.web.port"
    value = "80"
  }

  set {
    name  = "ports.websecure.port"
    value = "443"
  }

  set {
    name  = "ports.websecure.tls.enabled"
    value = "true"
  }

  set {
    name  = "ingressClass.enabled"
    value = "true"
  }

  set {
    name  = "ingressClass.isDefaultClass"
    value = "true"
  }

  values = [
    yamlencode({
      commonLabels = local.common_labels
      ingressRoute = {
        dashboard = {
          enabled     = var.enable_traefik_dashboard
          entryPoints = ["web"]
          matchRule   = "Host(`traefik.${var.base_domain}`)"
        }
      }
    })
  ]
}

resource "kubernetes_ingress_class_v1" "traefik" {
  for_each   = var.enable_traefik ? toset(["enabled"]) : toset([])
  depends_on = [null_resource.k3s_install]

  metadata {
    name   = "traefik"
    labels = local.common_labels
  }

  spec {
    controller = "traefik.io/ingress-controller"
  }
}
