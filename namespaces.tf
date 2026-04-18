resource "kubernetes_namespace_v1" "namespaces" {
  for_each   = toset(var.namespaces)
  depends_on = [null_resource.k3s_install]

  metadata {
    name   = each.key
    labels = local.common_labels
  }
}
