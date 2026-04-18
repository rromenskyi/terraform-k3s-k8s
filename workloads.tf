# Optional demo StatefulSet that exercises persistent storage via the k3s
# built-in local-path-provisioner. The pod runs non-root with a read-only root
# filesystem, all Linux capabilities dropped, and bounded resources — i.e.,
# compatible with a `restricted` PodSecurity level, not just `baseline`.

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
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name    = "ops"
          image   = var.ops_image
          command = ["sh", "-c", "tail -f /dev/null"]

          security_context {
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 1000

            capabilities {
              drop = ["ALL"]
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "16Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

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
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.ops_storage_class_name
        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }
}
