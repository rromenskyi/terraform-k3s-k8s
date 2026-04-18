# --------------------------------------------------------------------------
# Cluster identity
# --------------------------------------------------------------------------

variable "cluster_name" {
  description = "Logical name of the k3s cluster (used in labels and kubeconfig context)"
  type        = string
  default     = "tf-local"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}$", var.cluster_name))
    error_message = "Cluster name must be lowercase alphanumeric with hyphens, max 63 characters."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for k3s (for example `v1.31.4+k3s1`). Empty string means `latest` from the selected channel."
  type        = string
  default     = ""
}

variable "k3s_channel" {
  description = "k3s release channel (stable, latest, v1.31, etc). Only used when kubernetes_version is empty."
  type        = string
  default     = "stable"
}

variable "k3s_disable" {
  description = "List of built-in k3s components to disable. `traefik` is always disabled by this module because Traefik is managed via Helm."
  type        = list(string)
  default     = ["traefik"]
}

variable "k3s_extra_args" {
  description = "Additional raw arguments appended to the k3s server command (escape hatch for uncommon flags)."
  type        = list(string)
  default     = []
}

# --------------------------------------------------------------------------
# SSH connection to the target host (use 127.0.0.1 for a local install)
# --------------------------------------------------------------------------

variable "ssh_host" {
  description = "Host where k3s will be installed. Use `127.0.0.1` for a local install (the loopback SSH path keeps the bootstrap identical for local and remote targets)."
  type        = string
  default     = "127.0.0.1"
}

variable "ssh_port" {
  description = "SSH port on the target host"
  type        = number
  default     = 22
}

variable "ssh_user" {
  description = "SSH user with passwordless sudo on the target host"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key used to authenticate against the target host"
  type        = string
}

# --------------------------------------------------------------------------
# Cluster networking
# --------------------------------------------------------------------------

variable "service_cidr" {
  description = "CIDR range for Kubernetes Services (ClusterIP)"
  type        = string
  default     = "100.64.0.0/13"

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "service_cidr must be a valid CIDR block."
  }
}

variable "pod_cidr" {
  description = "CIDR range for Pods"
  type        = string
  default     = "100.72.0.0/13"

  validation {
    condition     = can(cidrhost(var.pod_cidr, 0))
    error_message = "pod_cidr must be a valid CIDR block."
  }
}

variable "dns_ip" {
  description = "IP address for CoreDNS (must be inside service_cidr)"
  type        = string
  default     = "100.64.0.10"
}

variable "cni" {
  description = "CNI to use. `flannel` uses the k3s built-in backend. `none` disables flannel so a third-party CNI (calico, cilium) can be installed separately."
  type        = string
  default     = "flannel"

  validation {
    condition     = contains(["flannel", "none"], var.cni)
    error_message = "cni must be one of: flannel, none."
  }
}

# --------------------------------------------------------------------------
# Platform add-ons
# --------------------------------------------------------------------------

variable "namespaces" {
  description = "Additional namespaces to create"
  type        = list(string)
  default     = ["ops", "monitoring"]
}

variable "namespace" {
  description = "Kubernetes namespace for the demo workload"
  type        = string
  default     = "default"
}

variable "enable_traefik" {
  description = "Deploy Traefik as Ingress controller via Helm"
  type        = bool
  default     = true
}

variable "enable_traefik_dashboard" {
  description = "Expose the Traefik dashboard via IngressRoute"
  type        = bool
  default     = true
}

variable "traefik_version" {
  description = "Traefik Helm chart version"
  type        = string
  default     = "34.2.0"
}

variable "enable_cert_manager" {
  description = "Deploy cert-manager + Let's Encrypt ClusterIssuers"
  type        = bool
  default     = true
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.16.1"
}

variable "letsencrypt_email" {
  description = "Email address registered with Let's Encrypt (required when cert-manager is enabled)"
  type        = string
  default     = "admin@example.com"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.letsencrypt_email))
    error_message = "letsencrypt_email must be a valid email address."
  }
}

variable "enable_monitoring" {
  description = "Deploy Prometheus + Grafana via kube-prometheus-stack"
  type        = bool
  default     = true
}

# --------------------------------------------------------------------------
# Demo workload
# --------------------------------------------------------------------------

variable "create_ops_workload" {
  description = "Whether to create the ops StatefulSet demo workload"
  type        = bool
  default     = true
}

variable "ops_image" {
  description = "Container image for the ops demo workload"
  type        = string
  default     = "alpine:3.20"
}
