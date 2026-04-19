output "cluster_name" {
  description = "Name of the created k3s cluster"
  value       = var.cluster_name
}

output "cluster_distribution" {
  description = "Which Kubernetes distribution this module provisions. Lets consumer modules (e.g. `terraform-k8s-addons`) branch on distribution programmatically instead of hardcoding a source path."
  value       = "k3s"
}

output "cluster_host" {
  description = "Kubernetes API server URL"
  value       = local.kubeconfig.host
}

output "client_certificate" {
  description = "Client certificate (PEM) for authentication"
  value       = local.kubeconfig.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key (PEM) for authentication"
  value       = local.kubeconfig.client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM)"
  value       = local.kubeconfig.cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Local path to the fetched kubeconfig file for this cluster. Wire this into `module \"addons\" { kubeconfig_path = module.k8s.kubeconfig_path }` in the platform root. The explicit `depends_on` makes downstream consumers wait for the kubeconfig file to actually land on disk: the underlying value is a plan-time-known string, so without this dep the Terraform graph lets addon-layer resources start racing the SSH-driven `null_resource.k3s_install` and they hit `connection refused` before the k3s API server is up."
  value       = local.kubeconfig_path
  depends_on = [
    null_resource.k3s_install,
    data.local_sensitive_file.kubeconfig,
  ]
}

output "kubeconfig_command" {
  description = "Shell command to export this cluster's kubeconfig for kubectl/helm"
  value       = "export KUBECONFIG='${local.kubeconfig_path}'"
}

output "service_cidr" {
  description = "Configured Service CIDR"
  value       = var.service_cidr
}

output "pod_cidr" {
  description = "Configured Pod CIDR"
  value       = var.pod_cidr
}

output "dns_ip" {
  description = "CoreDNS IP address"
  value       = var.dns_ip
}

output "k3s_disabled_components" {
  description = "Built-in k3s components disabled by this module"
  value       = local.k3s_effective_disable
}

output "access_instructions" {
  description = "Helpful commands to interact with the cluster"
  value = {
    export_kubeconfig = "export KUBECONFIG='${local.kubeconfig_path}'"
    get_nodes         = "kubectl --kubeconfig '${local.kubeconfig_path}' get nodes -o wide"
    get_pods          = "kubectl --kubeconfig '${local.kubeconfig_path}' get pods -A"
    k3s_logs          = "ssh ${var.ssh_user}@${var.ssh_host} 'sudo journalctl -u k3s -n 200 --no-pager'"
  }
}
