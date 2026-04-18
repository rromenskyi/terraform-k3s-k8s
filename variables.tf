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

variable "install_k3s" {
  description = "Whether this module installs k3s on the target host. Set to `false` to adopt an existing k3s service installed out-of-band (e.g. by `curl -sfL https://get.k3s.io | sh -` run manually or by a configuration-management tool). When false, the module skips the installer and the uninstaller, just fetches the kubeconfig, and trusts that the existing k3s config is compatible — the `service_cidr`, `pod_cidr`, `dns_ip`, `k3s_disable`, and `k3s_extra_args` variables become informational."
  type        = bool
  default     = true
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

variable "namespace_pod_security_level" {
  description = "Pod Security Standards level applied to module-managed namespaces (enforce + audit + warn). `baseline` is a safe default for most workloads. `restricted` is the strictest and may break Helm charts that require privileged pods (kube-prometheus-stack's node-exporter, for example). `privileged` effectively disables enforcement."
  type        = string
  default     = "baseline"

  validation {
    condition     = contains(["privileged", "baseline", "restricted"], var.namespace_pod_security_level)
    error_message = "namespace_pod_security_level must be one of: privileged, baseline, restricted."
  }
}

variable "enable_namespace_limits" {
  description = "Apply a default `ResourceQuota` and `LimitRange` to each module-managed namespace. Disable only if you enforce quotas out-of-band."
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Kubernetes namespace for the demo workload"
  type        = string
  default     = "default"
}

variable "base_domain" {
  description = "Base domain used to derive default hostnames for Traefik dashboard (`traefik.<base>`) and Grafana (`grafana.<base>`). Defaults to `localhost` for local k3s usage; set to a real domain (e.g. `dev.example.com`) for remote access."
  type        = string
  default     = "localhost"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.base_domain))
    error_message = "base_domain must be a valid DNS label sequence (lowercase alphanumerics, dots, hyphens)."
  }
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

variable "kube_prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "70.0.0"
}

variable "letsencrypt_email" {
  description = "Email address registered with Let's Encrypt (required when cert-manager is enabled). Must be a real mailbox — Let's Encrypt rate-limits RFC-2606 reserved domains (example.com, example.org, example.net, example.invalid, test, localhost) and does not issue certificates to them."
  type        = string
  default     = "admin@example.com"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.letsencrypt_email))
    error_message = "letsencrypt_email must be a valid email address."
  }

  validation {
    condition     = !can(regex("@(example\\.(com|org|net|invalid)|test|localhost)$", var.letsencrypt_email))
    error_message = "letsencrypt_email must not use an RFC-2606 reserved domain (example.com, example.org, example.net, example.invalid, test, localhost) — Let's Encrypt rejects those."
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

variable "ops_storage_class_name" {
  description = "StorageClass used by the ops StatefulSet's PVC. Default matches k3s' built-in `local-path-provisioner`. Set to `null` to rely on the cluster default StorageClass, or pin to a class you install yourself."
  type        = string
  default     = "local-path"
}
