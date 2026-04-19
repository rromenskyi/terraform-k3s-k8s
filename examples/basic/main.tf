terraform {
  required_version = ">= 1.5.0"
}

# Minimal k3s cluster bootstrap. The module writes a kubeconfig to
# `${path.root}/.terraform/k3s-<cluster_name>.kubeconfig` and exposes it as
# `module.k3s.kubeconfig_path`. The addon layer (Traefik, cert-manager,
# kube-prometheus-stack, ...) lives in the sibling `terraform-k8s-addons`
# module — compose it on top by consuming `kubeconfig_path`.
module "k3s" {
  source = "../../"

  cluster_name = "dev"

  # Local bootstrap — SSH into this machine over loopback. Point at a remote
  # host by flipping ssh_host.
  ssh_host             = "127.0.0.1"
  ssh_user             = "dev"
  ssh_private_key_path = "~/.ssh/id_ed25519"
}

output "kubeconfig_path" {
  value = module.k3s.kubeconfig_path
}

output "cluster_info" {
  value = {
    name         = module.k3s.cluster_name
    distribution = module.k3s.cluster_distribution
    host         = module.k3s.cluster_host
  }
}
