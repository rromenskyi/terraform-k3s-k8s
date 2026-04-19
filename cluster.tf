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

  # k3s ships a built-in Traefik by default; this module always disables it
  # because the sibling `terraform-k8s-addons` module installs a
  # Helm-managed Traefik and the two would conflict. Any additional
  # components the operator wants to disable go through `var.k3s_disable`.
  k3s_effective_disable = distinct(concat(["traefik"], var.k3s_disable))

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
    # Captured so the destroy provisioner knows whether this module owns the
    # k3s install and may therefore run the uninstaller.
    install_k3s = tostring(var.install_k3s)
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
  #
  # When `var.install_k3s = false` the installer step is skipped and this
  # module adopts an existing k3s service on the host. The wait steps still
  # run — they verify the pre-installed k3s is actually healthy before the
  # kubeconfig fetch and the rest of the plan proceeds.
  provisioner "remote-exec" {
    # The installer returns as soon as the systemd unit is active, but the
    # API server, kubelet, and CNI need a few more seconds to fully come
    # up. There are four distinct readiness milestones — wait for each one
    # in order before the provisioner returns. Missing any of them caused
    # downstream addon resources to start racing the cluster during
    # earlier bring-ups: connection refused, "no matching resources
    # found", or transient `FailedCreatePodSandBox` because flannel had
    # not yet written its subnet file.
    inline = concat([
      "set -euo pipefail",
      var.install_k3s ? local.k3s_install_command : "echo 'install_k3s=false; adopting pre-installed k3s on this host'",

      #   1. Kubeconfig written — `/etc/rancher/k3s/k3s.yaml` is the first
      #      artifact the API server produces on start.
      "until sudo test -s /etc/rancher/k3s/k3s.yaml; do sleep 1; done",

      #   2. Node registered with the API. `kubectl wait` with `--all` does
      #      NOT wait for resources to *exist* — if the node has not yet
      #      registered, it immediately errors out with "no matching
      #      resources found" and exits 1. Poll the node list first so
      #      that by the time we call `kubectl wait`, there is at least
      #      one Node to wait on.
      "timeout 120 bash -c 'until sudo k3s kubectl get nodes -o name 2>/dev/null | grep -q .; do sleep 2; done'",

      #   3. Node has the Ready condition true.
      "sudo k3s kubectl wait --for=condition=Ready node --all --timeout=120s",
      ], var.cni == "flannel" ? [
      #   4. Flannel wrote `/run/flannel/subnet.env` — the file kubelet's
      #      CNI plugin reads to set up pod sandboxes. The kubelet and
      #      flannel agent come up concurrently, so during the first
      #      seconds after the node goes Ready the CNI plugin can still
      #      fail with `failed to load flannel 'subnet.env' file`. Waiting
      #      here lets the first addon pods create their sandboxes on the
      #      first try instead of eating a retry backoff cycle. This step
      #      is skipped when `var.cni = "none"` (operator brings their own
      #      CNI and is expected to handle readiness themselves).
      "timeout 60 bash -c 'until sudo test -s /run/flannel/subnet.env; do sleep 1; done'",
    ] : [])
  }

  # Fetch kubeconfig locally and rewrite the server address for non-loopback hosts.
  # Values flow through `environment` rather than HCL string interpolation so
  # a path, host, or user containing shell metacharacters cannot break the
  # script. HCL heredocs interpolate `${...}` but leave `$VAR` literal, so
  # the bash variables below are not touched by Terraform.
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG_PATH = self.triggers.kubeconfig_path
      SSH_KEY         = self.triggers.ssh_key_path
      SSH_HOST        = self.triggers.ssh_host
      SSH_PORT        = tostring(self.triggers.ssh_port)
      SSH_USER        = self.triggers.ssh_user
    }
    command = <<-EOT
      set -euo pipefail
      umask 077
      mkdir -p "$(dirname "$KUBECONFIG_PATH")"
      ssh -i "$SSH_KEY" -p "$SSH_PORT" \
          -o StrictHostKeyChecking=accept-new \
          "$SSH_USER@$SSH_HOST" \
          'sudo cat /etc/rancher/k3s/k3s.yaml' > "$KUBECONFIG_PATH"
      case "$SSH_HOST" in
        127.0.0.1|localhost) ;;
        *) sed -i "s#server: https://127.0.0.1:6443#server: https://$SSH_HOST:6443#" "$KUBECONFIG_PATH" ;;
      esac
      chmod 600 "$KUBECONFIG_PATH"
    EOT
  }

  # Run the official k3s uninstaller on destroy, then drop the local kubeconfig.
  # Only when this module owned the install — `install_k3s=false` means the
  # user adopted a pre-existing k3s service, and the module must not remove
  # something it did not create.
  #
  # `on_failure = continue` is mandatory: if the target host is offline or the
  # SSH identity has rotated, a blocking destroy would hang for the
  # connection timeout and then fail, leaving the state stuck. Continue on
  # failure so that `terraform destroy` always finishes; operators can clean
  # up a stranded k3s install on the host manually if needed.
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "if [ \"${self.triggers.install_k3s}\" = \"true\" ] && [ -x /usr/local/bin/k3s-uninstall.sh ]; then sudo /usr/local/bin/k3s-uninstall.sh; fi",
    ]
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG_PATH = self.triggers.kubeconfig_path
    }
    command = "rm -f \"$KUBECONFIG_PATH\""
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
