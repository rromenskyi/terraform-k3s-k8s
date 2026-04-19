# --------------------------------------------------------------------------
# Cluster identity
# --------------------------------------------------------------------------

variable "cluster_name" {
  description = "Logical name of the k3s cluster (used in labels and the kubeconfig filename)"
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
  description = "k3s release channel (stable, latest, v1.31, etc.). Only used when kubernetes_version is empty."
  type        = string
  default     = "stable"
}

variable "k3s_disable" {
  description = "List of built-in k3s components to disable. `traefik` is always disabled by this module because the ingress controller is managed by the sibling `terraform-k8s-addons` module."
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
