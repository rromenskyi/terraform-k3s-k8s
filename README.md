# terraform-k3s-k8s

**Terraform module that bootstraps a k3s cluster on a target host via SSH
and exposes its kubeconfig.**

> Sibling to [`terraform-minikube-k8s`](https://github.com/rromenskyi/terraform-minikube-k8s).
> Same output contract (`cluster_host`, `client_certificate`, `client_key`,
> `cluster_ca_certificate`, `kubeconfig_path`, `cluster_name`,
> `cluster_distribution`) so either module can drive the shared addons
> layer on top. Status: **v0.3.0 and up** — the addon layer has been lifted
> out into [`terraform-k8s-addons`](https://github.com/rromenskyi/terraform-k8s-addons);
> this module is cluster-bootstrap only. Migrating from v0.2.x: keep your
> cluster-shape inputs, add a sibling `module "addons"` block and move the
> `enable_traefik`, `enable_cert_manager`, `enable_monitoring`,
> `create_ops_workload`, `letsencrypt_email`, `base_domain`, `namespaces`,
> and `*_version` inputs there.

## Scope

This module owns only the distribution-specific concerns of running k3s:

- SSH into the target host (local loopback by default, remote supported)
- Run the official installer (`curl -sfL https://get.k3s.io | sh -`) or
  adopt an already-running k3s via `install_k3s = false`
- Wait for the API server, the node registration, the node's `Ready`
  condition, and (for flannel deployments) `/run/flannel/subnet.env`
- Fetch and rewrite the kubeconfig, expose its path at
  `kubeconfig_path`
- Run the official uninstaller on `terraform destroy`

Everything else — Traefik, cert-manager, Let's Encrypt issuers,
kube-prometheus-stack, PodSecurity-labeled namespaces, demo workloads —
lives in `terraform-k8s-addons` and consumes `module.k3s.kubeconfig_path`.

## Requirements on the target host

- SSH daemon reachable at `ssh_host:ssh_port`
- An SSH user with **passwordless sudo**
- The SSH private key referenced by `ssh_private_key_path` trusted by that
  user

Use `127.0.0.1` + your local user for a single-box setup; the code path is
identical for remote targets.

## Composition example

```hcl
module "k3s" {
  source = "git::https://github.com/rromenskyi/terraform-k3s-k8s.git?ref=v0.3.0"

  cluster_name         = "home-lab"
  ssh_host             = "10.0.0.5"
  ssh_user             = "ops"
  ssh_private_key_path = "~/.ssh/id_ed25519"

  # Optional: pin the k3s version, otherwise the stable channel wins.
  # kubernetes_version = "v1.31.4+k3s1"
}

module "addons" {
  source = "git::https://github.com/rromenskyi/terraform-k8s-addons.git?ref=v0.1.0"

  kubeconfig_path      = module.k3s.kubeconfig_path
  cluster_name         = module.k3s.cluster_name
  cluster_distribution = module.k3s.cluster_distribution
  letsencrypt_email    = "you@yourdomain.example"
}
```

## Adopting a pre-installed k3s (`install_k3s = false`)

If k3s is already running — manually installed, baked into an image,
managed by configuration tooling outside Terraform — set
`install_k3s = false`:

```hcl
module "k3s" {
  source = "git::https://github.com/rromenskyi/terraform-k3s-k8s.git?ref=v0.3.0"

  install_k3s          = false
  cluster_name         = "home-lab"
  ssh_host             = "10.0.0.5"
  ssh_user             = "ops"
  ssh_private_key_path = "~/.ssh/id_ed25519"
}
```

Behavior in this mode:

- The installer (`curl | sh`) is skipped, the uninstaller (`k3s-uninstall.sh`)
  is skipped on destroy — the module never touches the k3s service
  lifecycle.
- The readiness waits (`k3s.yaml`, node registration, node `Ready`,
  flannel `subnet.env`) still run. They double as a health check and as
  a precondition before the kubeconfig fetch.
- Cluster-shape inputs (`service_cidr`, `pod_cidr`, `dns_ip`, `cni`,
  `k3s_disable`, `k3s_extra_args`, `kubernetes_version`, `k3s_channel`)
  become **informational**. The module does not reconcile them against
  the running install.

## Consumer provider wiring

The downstream `kubernetes` / `helm` providers **must** read the cluster
via `config_path`, not inline `host` / `client_certificate` /
`cluster_ca_certificate` attributes:

```hcl
provider "kubernetes" {
  config_path = module.k3s.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = module.k3s.kubeconfig_path
  }
}
```

`kubeconfig_path` is a plan-time-known string, and `config_path` is opened
lazily at resource-apply time. The consumer can therefore plan before the
kubeconfig file exists on disk; by the time any API call is made, the
installer has written it. This is what makes a **single-phase**
`terraform apply` work against a cold state. Inline cert attributes
resolve at plan time and reintroduce the chicken-and-egg first-apply
problem — don't use them.

Internally, the `kubeconfig_path` output carries an explicit
`depends_on = [null_resource.k3s_install, data.local_sensitive_file.kubeconfig]`
so downstream modules do not start racing the installer.

## Quick start

```bash
cd examples/basic
# edit main.tf to set ssh_host / ssh_user / ssh_private_key_path
terraform init
terraform apply
```

After deployment:

```bash
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
kubectl get nodes -o wide
```

## What's in the repo

- `cluster.tf` — k3s install over SSH, staged readiness waits, kubeconfig
  fetch, decoded locals
- `outputs.tf` — `kubeconfig_path`, cluster host + certs, CIDR echo
- `variables.tf` — cluster-shape inputs only (no addon flags)
- `_providers.tf`, `_versions.tf` — `null` + `local` providers; the
  consumer configures `kubernetes` / `helm`
- `examples/basic`, `examples/demo` — minimal and full platform examples

## Development

```bash
pip install pre-commit
pre-commit install
pre-commit run -a
```

## License

MIT — see [LICENSE](LICENSE).
