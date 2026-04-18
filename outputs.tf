output "cluster_name" {
  description = "Name of the created k3s cluster"
  value       = var.cluster_name
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
  description = "Local path to the fetched kubeconfig file for this cluster"
  value       = local.kubeconfig_path
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

output "namespaces" {
  description = "Created namespaces"
  value       = [for ns in kubernetes_namespace_v1.namespaces : ns.metadata[0].name]
}

output "ops_statefulset_name" {
  description = "Name of the ops StatefulSet (if created)"
  value       = var.create_ops_workload ? kubernetes_stateful_set_v1.ops["enabled"].metadata[0].name : null
}

output "traefik_enabled" {
  description = "Whether Traefik is enabled"
  value       = var.enable_traefik
}

output "cert_manager_enabled" {
  description = "Whether cert-manager is enabled"
  value       = var.enable_cert_manager
}

output "monitoring_enabled" {
  description = "Whether Prometheus + Grafana stack is enabled"
  value       = var.enable_monitoring
}

output "ingress_class" {
  description = "IngressClass name (Traefik)"
  value       = var.enable_traefik ? "traefik" : null
}

output "grafana_url" {
  description = "Grafana URL (resolves against the Traefik ingress; add it to /etc/hosts or your DNS)"
  value       = var.enable_monitoring ? "https://grafana.${var.base_domain}" : null
}

output "grafana_credentials" {
  description = "Grafana login credentials (password is randomly generated and kept in Terraform state)"
  value = var.enable_monitoring ? {
    url      = "https://grafana.${var.base_domain}"
    username = "admin"
    password = random_password.grafana["enabled"].result
  } : null
  sensitive = true
}

output "traefik_dashboard_url" {
  description = "Traefik dashboard URL (if enabled)"
  value       = var.enable_traefik && var.enable_traefik_dashboard ? "http://traefik.${var.base_domain}" : null
}

output "access_instructions" {
  description = "Helpful commands to interact with the cluster"
  value = {
    export_kubeconfig = "export KUBECONFIG='${local.kubeconfig_path}'"
    get_nodes         = "kubectl --kubeconfig '${local.kubeconfig_path}' get nodes -o wide"
    get_pods          = "kubectl --kubeconfig '${local.kubeconfig_path}' get pods -A"
    get_ingress       = var.enable_traefik ? "kubectl --kubeconfig '${local.kubeconfig_path}' get ingress -A" : null
    k3s_logs          = "ssh ${var.ssh_user}@${var.ssh_host} 'sudo journalctl -u k3s -n 200 --no-pager'"
  }
}
