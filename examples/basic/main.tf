terraform {
  required_version = ">= 1.5.0"
}

module "k3s" {
  source = "../../"

  cluster_name = "my-dev-cluster"

  # Local bootstrap: SSH into this machine (loopback).
  ssh_host             = "127.0.0.1"
  ssh_user             = "dev"
  ssh_private_key_path = "~/.ssh/id_ed25519"

  create_ops_workload = true
  ops_image           = "nginx:alpine"
  namespace           = "ops"

  # 100.64.0.0/10 CGNAT range avoids conflicts with home/office networks.
  service_cidr = "100.64.0.0/13"
  pod_cidr     = "100.72.0.0/13"
  dns_ip       = "100.64.0.10"

  namespaces     = ["ops", "monitoring", "apps"]
  enable_traefik = true
}

output "kubeconfig_path" {
  value = module.k3s.kubeconfig_path
}

output "export_kubeconfig_cmd" {
  value = module.k3s.kubeconfig_command
}

output "cluster_info" {
  value = {
    name    = module.k3s.cluster_name
    host    = module.k3s.cluster_host
    ops_pod = module.k3s.ops_statefulset_name
  }
}
