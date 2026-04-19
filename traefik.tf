resource "helm_release" "traefik" {
  for_each   = var.enable_traefik ? toset(["enabled"]) : toset([])
  depends_on = [null_resource.k3s_install]

  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_version
  # Match the sibling `terraform-minikube-k8s` module: the ingress controller
  # lives in its role-named namespace `ingress-controller` rather than
  # `traefik` so downstream stacks (platform cheatsheets, NetworkPolicies,
  # docs) can address it identically regardless of distribution.
  namespace        = "ingress-controller"
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
