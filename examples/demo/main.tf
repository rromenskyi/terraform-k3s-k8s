terraform {
  required_version = ">= 1.5.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = module.k3s.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = module.k3s.kubeconfig_path
  }
}

module "k3s" {
  source = "../../"

  cluster_name = "demo-cluster"

  ssh_host             = "127.0.0.1"
  ssh_user             = "dev"
  ssh_private_key_path = "~/.ssh/id_ed25519"

  cni          = "flannel"
  service_cidr = "100.64.0.0/13"
  pod_cidr     = "100.72.0.0/13"
  dns_ip       = "100.64.0.10"

  namespaces               = ["apps", "monitoring"]
  enable_traefik           = true
  enable_traefik_dashboard = true
  enable_cert_manager      = true
  enable_monitoring        = true
  letsencrypt_email        = "demo@example.com"
}

resource "kubernetes_deployment_v1" "demo_app" {
  depends_on = [module.k3s]

  metadata {
    name      = "demo-app"
    namespace = "apps"
    labels    = { app = "demo" }
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "demo" }
    }

    template {
      metadata {
        labels = { app = "demo" }
      }

      spec {
        container {
          name  = "app"
          image = "nginx:alpine"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "demo_app" {
  depends_on = [module.k3s]

  metadata {
    name      = "demo-app"
    namespace = "apps"
  }

  spec {
    selector = { app = "demo" }
    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "helm_release" "demo_certificate" {
  depends_on = [module.k3s]

  name             = "demo-certificate"
  chart            = "${path.module}/charts/demo-certificate"
  namespace        = "apps"
  create_namespace = true
}

resource "kubernetes_ingress_v1" "demo_ingress" {
  depends_on = [helm_release.demo_certificate]

  metadata {
    name      = "demo-ingress"
    namespace = "apps"
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls"         = "true"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "demo.localhost"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "demo-app"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    tls {
      secret_name = "demo-tls"
      hosts       = ["demo.localhost"]
    }
  }
}

output "demo_urls" {
  value = {
    app_url           = "https://demo.localhost"
    traefik_url       = "http://traefik.localhost"
    traefik_dashboard = "http://traefik.localhost/dashboard/"
    grafana_url       = "https://grafana.localhost"
    note              = "Grafana password: terraform output -json grafana_credentials | jq -r '.value.password'"
  }
}

output "module_outputs" {
  value = module.k3s.access_instructions
}
