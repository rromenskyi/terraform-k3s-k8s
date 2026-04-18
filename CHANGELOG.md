# terraform-k3s-k8s Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `cluster_distribution` output (value: `"k3s"`) lets sibling-module consumers programmatically branch on which distribution is active without hardcoding the source path
- `base_domain` variable (default: `"localhost"`). Traefik dashboard and Grafana hostnames are now derived as `traefik.<base_domain>` and `grafana.<base_domain>` instead of hardcoded `*.localhost`. Also surfaces a new `traefik_dashboard_url` output.
- `ops_storage_class_name` variable pins the StorageClass used by the ops StatefulSet's PVC (default: `"local-path"`, matching k3s' built-in local-path-provisioner)
- Pod Security Standards labels (`enforce`/`audit`/`warn`) applied to every module-managed namespace via the new `namespace_pod_security_level` variable (default: `baseline`)
- Default `kubernetes_resource_quota_v1` (4/8 CPU requests/limits, 8Gi/16Gi memory, 50 pods) and `kubernetes_limit_range_v1` (100m/128Mi request, 500m/512Mi limit per container) applied to each module-managed namespace. Gated by the new `enable_namespace_limits` variable (default: `true`)
- `ops` StatefulSet now runs with a hardened `security_context`: `runAsNonRoot`, UID/GID 1000, `readOnlyRootFilesystem`, all Linux capabilities dropped, `RuntimeDefault` seccomp profile, and bounded `resources.requests`/`limits` — i.e., compatible with `restricted` PodSecurity

### Fixed
- kube-prometheus-stack no longer creates its own Grafana Ingress. The chart-side `grafana.ingress.*` settings were stripped from the Helm release, so the only Ingress targeting `grafana.localhost` is now the Terraform-managed `kubernetes_ingress_v1.grafana` (which carries the required Traefik router annotations). Removes a duplicate Ingress with conflicting ownership on the same host.
- `local-exec` provisioners that fetch and clean up the kubeconfig now pass SSH host/user/port/key path and the kubeconfig path through `environment = { ... }` instead of inline HCL string interpolation wrapped in bash single quotes. Paths, hostnames, or usernames containing shell metacharacters can no longer break the script. Added `umask 077` during kubeconfig write for defense in depth.
- `null_resource.k3s_install` triggers no longer include the rendered install command. Editing `service_cidr`, `pod_cidr`, `kubernetes_version`, `k3s_channel`, `k3s_disable`, or `k3s_extra_args` no longer silently destroys and reinstalls the live cluster on the next apply. Reshaping the install now requires an explicit `terraform taint` on the `null_resource`.
- Destroy-time `remote-exec` provisioner now uses `on_failure = continue`, so `terraform destroy` completes even when the target host is unreachable or the SSH identity has rotated. Previously the provisioner blocked for the connection timeout and then failed, leaving state stuck.

## [0.1.0] - 2026-04-18

**Status: alpha.** Sibling module to `terraform-minikube-k8s`, same platform layer (Traefik, cert-manager, kube-prometheus-stack, namespaces, demo ops StatefulSet) on top of a k3s cluster bootstrapped via SSH.

### Added
- k3s cluster bootstrap through `null_resource` + SSH `remote-exec` invoking the official installer (`curl -sfL https://get.k3s.io | ... sh -`)
- Automatic kubeconfig fetch from the target host with loopback/remote host rewrite
- `config_path`-based kubernetes/helm provider wiring, compatible with the two-phase first-apply workaround
- Signature-compatible outputs with `terraform-minikube-k8s` (`cluster_host`, `client_certificate`, `client_key`, `cluster_ca_certificate`, `grafana_credentials`, `ingress_class`, etc.)
- Traefik Helm release + IngressClass + optional dashboard IngressRoute
- cert-manager Helm release + Let's Encrypt staging/production ClusterIssuers via local chart
- kube-prometheus-stack release with Grafana ingress on Traefik and randomly-generated admin password
- Demo ops StatefulSet exercising k3s local-path-provisioner
- Examples: `examples/basic` (minimal) and `examples/demo` (full platform with demo app, TLS, Grafana)
- `AGENT.md` and `skills/` directory mirrored from the minikube module

### Known Limitations
- First-time apply requires `terraform apply -target=null_resource.k3s_install` before the full apply because the kubernetes provider errors on a missing kubeconfig during plan
- Target host must have passwordless `sudo` for the configured SSH user
- Single-node only for now; multi-server/agent support deferred
