# k3s cluster bootstrap.
#
# Installs k3s on the host reachable via SSH (127.0.0.1 by default for a local
# install). Kubeconfig is fetched back to ${path.root}/.terraform/ so the
# kubernetes and helm providers — both this module's and the consumer's —
# can point at it via `config_path`, which is opened lazily at resource-apply
# time and therefore does not need the file to exist during plan.
#
# Single-phase `terraform apply` works from a cold state. Do not wire
# downstream providers through inline host/cert attributes; that reintroduces
# the two-phase `-target=null_resource.k3s_install` problem.

locals {
  kubeconfig_path = "${path.root}/.terraform/k3s-${var.cluster_name}.kubeconfig"

  k3s_effective_disable = distinct(concat(
    var.enable_traefik ? ["traefik"] : [],
    var.k3s_disable,
  ))

  k3s_exec_args = join(" ", concat(
    [for c in local.k3s_effective_disable : "--disable=${c}"],
    [
      "--cluster-cidr=${var.pod_cidr}",
      "--service-cidr=${var.service_cidr}",
      "--cluster-dns=${var.dns_ip}",
      "--write-kubeconfig-mode=644",
      "--tls-san=${var.ssh_host}",
    ],
    var.cni == "none" ? ["--flannel-backend=none"] : [],
    var.k3s_extra_args,
  ))

  k3s_install_env = join(" ", compact([
    var.kubernetes_version != "" ? "INSTALL_K3S_VERSION='${var.kubernetes_version}'" : "INSTALL_K3S_CHANNEL='${var.k3s_channel}'",
    "INSTALL_K3S_EXEC='server ${local.k3s_exec_args}'",
  ]))

  k3s_install_command = "curl -sfL https://get.k3s.io | ${local.k3s_install_env} sh -s -"
}

resource "null_resource" "k3s_install" {
  # `triggers` are intentionally identity- and access-only. `install_command`,
  # which includes CIDRs / `kubernetes_version` / `k3s_channel` / extra flags,
  # is DELIBERATELY omitted — if it were captured here, editing any of those
  # variables would silently destroy and reinstall the cluster on the next
  # apply, wiping every workload. Reshaping the install (version bump, CIDR
  # change, flag toggle) therefore requires an explicit intent:
  #
  #     terraform taint module.<name>.null_resource.k3s_install
  #     terraform apply
  #
  # Only `cluster_name` acts as true identity here. The SSH access fields
  # must be in `triggers` so the destroy-time provisioner can still reach the
  # host after the variables are no longer directly accessible.
  triggers = {
    cluster_name    = var.cluster_name
    ssh_host        = var.ssh_host
    ssh_port        = var.ssh_port
    ssh_user        = var.ssh_user
    ssh_key_path    = var.ssh_private_key_path
    kubeconfig_path = local.kubeconfig_path
  }

  connection {
    type        = "ssh"
    host        = self.triggers.ssh_host
    port        = self.triggers.ssh_port
    user        = self.triggers.ssh_user
    private_key = file(self.triggers.ssh_key_path)
    timeout     = "2m"
  }

  # Install k3s server and wait until the API responds. The create-time
  # provisioner can reference locals directly; only destroy-time provisioners
  # are restricted to `self.*`.
  provisioner "remote-exec" {
    inline = [
      "set -euo pipefail",
      local.k3s_install_command,
      # Installer returns once systemd unit is active; give the apiserver a moment.
      "until sudo test -s /etc/rancher/k3s/k3s.yaml; do sleep 1; done",
      "sudo k3s kubectl wait --for=condition=Ready node --all --timeout=120s",
    ]
  }

  # Fetch kubeconfig locally and rewrite the server address for non-loopback hosts.
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      mkdir -p "$(dirname '${self.triggers.kubeconfig_path}')"
      ssh -i '${self.triggers.ssh_key_path}' -p '${self.triggers.ssh_port}' \
          -o StrictHostKeyChecking=accept-new \
          '${self.triggers.ssh_user}@${self.triggers.ssh_host}' \
          'sudo cat /etc/rancher/k3s/k3s.yaml' > '${self.triggers.kubeconfig_path}'
      case '${self.triggers.ssh_host}' in
        127.0.0.1|localhost) ;;
        *) sed -i "s#server: https://127.0.0.1:6443#server: https://${self.triggers.ssh_host}:6443#" '${self.triggers.kubeconfig_path}' ;;
      esac
      chmod 600 '${self.triggers.kubeconfig_path}'
    EOT
  }

  # Run the official k3s uninstaller on destroy, then drop the local kubeconfig.
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "if [ -x /usr/local/bin/k3s-uninstall.sh ]; then sudo /usr/local/bin/k3s-uninstall.sh; fi",
    ]
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = "rm -f '${self.triggers.kubeconfig_path}'"
  }
}

# Kubeconfig content is needed for outputs (host + decoded certs). The data
# source is deferred via `depends_on` so it only reads after bootstrap.
data "local_sensitive_file" "kubeconfig" {
  depends_on = [null_resource.k3s_install]
  filename   = local.kubeconfig_path
}

locals {
  kubeconfig_decoded = yamldecode(data.local_sensitive_file.kubeconfig.content)
  kubeconfig = {
    host                   = local.kubeconfig_decoded.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig_decoded.clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig_decoded.users[0].user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig_decoded.users[0].user["client-key-data"])
  }
}
