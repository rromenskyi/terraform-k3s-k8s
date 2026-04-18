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
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.8.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.cluster_issuers](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.monitoring](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.traefik](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_ingress_class_v1.traefik](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_class_v1) | resource |
| [kubernetes_ingress_v1.grafana](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1) | resource |
| [kubernetes_namespace_v1.namespaces](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_stateful_set_v1.ops](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/stateful_set_v1) | resource |
| [null_resource.k3s_install](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_password.grafana](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [local_sensitive_file.kubeconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/sensitive_file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | cert-manager Helm chart version | `string` | `"v1.16.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Logical name of the k3s cluster (used in labels and kubeconfig context) | `string` | `"tf-local"` | no |
| <a name="input_cni"></a> [cni](#input\_cni) | CNI to use. `flannel` uses the k3s built-in backend. `none` disables flannel so a third-party CNI (calico, cilium) can be installed separately. | `string` | `"flannel"` | no |
| <a name="input_create_ops_workload"></a> [create\_ops\_workload](#input\_create\_ops\_workload) | Whether to create the ops StatefulSet demo workload | `bool` | `true` | no |
| <a name="input_dns_ip"></a> [dns\_ip](#input\_dns\_ip) | IP address for CoreDNS (must be inside service\_cidr) | `string` | `"100.64.0.10"` | no |
| <a name="input_enable_cert_manager"></a> [enable\_cert\_manager](#input\_enable\_cert\_manager) | Deploy cert-manager + Let's Encrypt ClusterIssuers | `bool` | `true` | no |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Deploy Prometheus + Grafana via kube-prometheus-stack | `bool` | `true` | no |
| <a name="input_enable_traefik"></a> [enable\_traefik](#input\_enable\_traefik) | Deploy Traefik as Ingress controller via Helm | `bool` | `true` | no |
| <a name="input_enable_traefik_dashboard"></a> [enable\_traefik\_dashboard](#input\_enable\_traefik\_dashboard) | Expose the Traefik dashboard via IngressRoute | `bool` | `true` | no |
| <a name="input_k3s_channel"></a> [k3s\_channel](#input\_k3s\_channel) | k3s release channel (stable, latest, v1.31, etc). Only used when kubernetes\_version is empty. | `string` | `"stable"` | no |
| <a name="input_k3s_disable"></a> [k3s\_disable](#input\_k3s\_disable) | List of built-in k3s components to disable. `traefik` is always disabled by this module because Traefik is managed via Helm. | `list(string)` | ```[ "traefik" ]``` | no |
| <a name="input_k3s_extra_args"></a> [k3s\_extra\_args](#input\_k3s\_extra\_args) | Additional raw arguments appended to the k3s server command (escape hatch for uncommon flags). | `list(string)` | `[]` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version for k3s (for example `v1.31.4+k3s1`). Empty string means `latest` from the selected channel. | `string` | `""` | no |
| <a name="input_letsencrypt_email"></a> [letsencrypt\_email](#input\_letsencrypt\_email) | Email address registered with Let's Encrypt (required when cert-manager is enabled) | `string` | `"admin@example.com"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for the demo workload | `string` | `"default"` | no |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | Additional namespaces to create | `list(string)` | ```[ "ops", "monitoring" ]``` | no |
| <a name="input_ops_image"></a> [ops\_image](#input\_ops\_image) | Container image for the ops demo workload | `string` | `"alpine:3.20"` | no |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | CIDR range for Pods | `string` | `"100.72.0.0/13"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | CIDR range for Kubernetes Services (ClusterIP) | `string` | `"100.64.0.0/13"` | no |
| <a name="input_ssh_host"></a> [ssh\_host](#input\_ssh\_host) | Host where k3s will be installed. Use `127.0.0.1` for a local install (the loopback SSH path keeps the bootstrap identical for local and remote targets). | `string` | `"127.0.0.1"` | no |
| <a name="input_ssh_port"></a> [ssh\_port](#input\_ssh\_port) | SSH port on the target host | `number` | `22` | no |
| <a name="input_ssh_private_key_path"></a> [ssh\_private\_key\_path](#input\_ssh\_private\_key\_path) | Path to the SSH private key used to authenticate against the target host | `string` | n/a | yes |
| <a name="input_ssh_user"></a> [ssh\_user](#input\_ssh\_user) | SSH user with passwordless sudo on the target host | `string` | n/a | yes |
| <a name="input_traefik_version"></a> [traefik\_version](#input\_traefik\_version) | Traefik Helm chart version | `string` | `"34.2.0"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_instructions"></a> [access\_instructions](#output\_access\_instructions) | Helpful commands to interact with the cluster |
| <a name="output_cert_manager_enabled"></a> [cert\_manager\_enabled](#output\_cert\_manager\_enabled) | Whether cert-manager is enabled |
| <a name="output_client_certificate"></a> [client\_certificate](#output\_client\_certificate) | Client certificate (PEM) for authentication |
| <a name="output_client_key"></a> [client\_key](#output\_client\_key) | Client key (PEM) for authentication |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Cluster CA certificate (PEM) |
| <a name="output_cluster_host"></a> [cluster\_host](#output\_cluster\_host) | Kubernetes API server URL |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the created k3s cluster |
| <a name="output_dns_ip"></a> [dns\_ip](#output\_dns\_ip) | CoreDNS IP address |
| <a name="output_grafana_credentials"></a> [grafana\_credentials](#output\_grafana\_credentials) | Grafana login credentials (password is randomly generated and kept in Terraform state) |
| <a name="output_grafana_url"></a> [grafana\_url](#output\_grafana\_url) | Grafana URL (resolves against the Traefik ingress; add it to /etc/hosts or your DNS) |
| <a name="output_ingress_class"></a> [ingress\_class](#output\_ingress\_class) | IngressClass name (Traefik) |
| <a name="output_k3s_disabled_components"></a> [k3s\_disabled\_components](#output\_k3s\_disabled\_components) | Built-in k3s components disabled by this module |
| <a name="output_kubeconfig_command"></a> [kubeconfig\_command](#output\_kubeconfig\_command) | Shell command to export this cluster's kubeconfig for kubectl/helm |
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | Local path to the fetched kubeconfig file for this cluster |
| <a name="output_monitoring_enabled"></a> [monitoring\_enabled](#output\_monitoring\_enabled) | Whether Prometheus + Grafana stack is enabled |
| <a name="output_namespaces"></a> [namespaces](#output\_namespaces) | Created namespaces |
| <a name="output_ops_statefulset_name"></a> [ops\_statefulset\_name](#output\_ops\_statefulset\_name) | Name of the ops StatefulSet (if created) |
| <a name="output_pod_cidr"></a> [pod\_cidr](#output\_pod\_cidr) | Configured Pod CIDR |
| <a name="output_service_cidr"></a> [service\_cidr](#output\_service\_cidr) | Configured Service CIDR |
| <a name="output_traefik_enabled"></a> [traefik\_enabled](#output\_traefik\_enabled) | Whether Traefik is enabled |
<!-- END_TF_DOCS -->
