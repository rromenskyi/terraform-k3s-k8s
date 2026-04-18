# Optional demo StatefulSet that exercises persistent storage via the k3s
# built-in local-path-provisioner. Serves as a smoke test for the cluster.

resource "kubernetes_stateful_set_v1" "ops" {
  for_each   = var.create_ops_workload ? toset(["enabled"]) : toset([])
  depends_on = [null_resource.k3s_install]

  metadata {
    name      = "ops"
    namespace = var.namespace
    labels    = merge(local.common_labels, { app = "ops" })
  }

  spec {
    service_name = "ops"
    replicas     = 1

    selector {
      match_labels = { app = "ops" }
    }

    template {
      metadata {
        labels = merge(local.common_labels, { app = "ops" })
      }

      spec {
        container {
          name    = "ops"
          image   = var.ops_image
          command = ["sh", "-c", "tail -f /dev/null"]

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        termination_grace_period_seconds = 10
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }
}
