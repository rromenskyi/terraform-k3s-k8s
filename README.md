# terraform-k3s-k8s

**A local Kubernetes platform module powered by Terraform and k3s.**

> **Status: alpha (v0.1.0).** Sibling to [`terraform-minikube-k8s`](https://github.com/rromenskyi/terraform-minikube-k8s). Same platform layer, k3s cluster bootstrap via SSH instead of the minikube provider. API is not yet frozen; expect breaking changes before 1.0.

This module is designed for a Terraform-first workflow: Terraform bootstraps k3s on the target host (local loopback by default) and then converges the platform services on top of it.

## Operating Model

- Terraform is the entrypoint for cluster lifecycle and platform rollout.
- k3s is installed via SSH + `remote-exec` using the official installer (`curl -sfL https://get.k3s.io | sh -`). The same code path targets `127.0.0.1` (local install) or a remote server.
- The target host must have:
  - An SSH daemon reachable at `ssh_host:ssh_port`
  - An SSH user with **passwordless sudo**
  - The SSH private key referenced by `ssh_private_key_path` trusted by that user
- Kubeconfig is fetched back to `${path.root}/.terraform/k3s-<cluster_name>.kubeconfig` and consumed by the `kubernetes` and `helm` providers via `config_path`.

Platform components included:

- **Traefik** — Ingress Controller with built-in Dashboard
- **cert-manager** + Let's Encrypt ClusterIssuers (staging + production)
- **Prometheus + Grafana** via `kube-prometheus-stack`
- Automatic namespace provisioning
- Demo `ops` StatefulSet exercising the built-in `local-path-provisioner`

## First-Time Bootstrap (two-phase apply)

The `kubernetes` provider errors during plan when its `config_path` points to a file that doesn't exist yet. On the first apply, bootstrap the cluster before planning the rest:

```bash
terraform init
terraform apply -target=null_resource.k3s_install
terraform apply
```

Subsequent applies don't need the `-target` hop.

## Quick Start

```bash
cd examples/demo
# Edit main.tf to set ssh_user, ssh_private_key_path, and letsencrypt_email
terraform init
terraform apply -target=module.k3s.null_resource.k3s_install
terraform apply
```

After deployment:

```bash
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
kubectl get nodes -o wide

# Grafana admin password
terraform output -json grafana_credentials | jq -r '.value.password'
```

Point `traefik.localhost`, `grafana.localhost`, and `demo.localhost` at your host IP (`/etc/hosts` or DNS) to reach the ingresses.

## What's Included

- `cluster.tf` — k3s bootstrap (null_resource + SSH), kubeconfig fetch, decoded locals
- `_versions.tf`, `_providers.tf` — provider requirements and wiring via `config_path`
- `traefik.tf` — Traefik Helm release + IngressClass + dashboard IngressRoute
- `cert_manager.tf` — cert-manager Helm release + Let's Encrypt ClusterIssuers
- `monitoring.tf` — kube-prometheus-stack + Grafana ingress
- `namespaces.tf` — extra namespaces
- `workloads.tf` — demo ops StatefulSet

## Examples

- [`examples/basic/`](examples/basic/) — Minimal configuration
- [`examples/demo/`](examples/demo/) — Full platform with demo app, TLS, and monitoring

## Development

### Pre-commit hooks (recommended)

```bash
pip install pre-commit
pre-commit install
pre-commit run -a
```

### Useful Commands

```bash
terraform output
terraform output -json grafana_credentials | jq -r '.value.password'

# Tail k3s logs on the target host
ssh <ssh_user>@<ssh_host> 'sudo journalctl -u k3s -n 200 --no-pager'
```

## AI Assistant Configuration

This repository includes `AGENT.md` and a `skills/` directory with structured engineering guidelines. These files encode Terraform, Kubernetes, SRE, and code quality best practices and are picked up by AI coding assistants with repository context.

---

**License:** MIT
**Author:** @rromenskyi

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs output is injected here by CI / pre-commit -->
<!-- END_TF_DOCS -->
