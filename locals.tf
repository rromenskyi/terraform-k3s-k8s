# Common labels and annotations applied across all Kubernetes resources.

locals {
  common_labels = {
    terraform   = "true"
    module      = "terraform-k3s-k8s"
    environment = "local"
    managed_by  = "terraform"
  }

  common_annotations = {
    "app.kubernetes.io/managed-by" = "terraform"
  }
}
