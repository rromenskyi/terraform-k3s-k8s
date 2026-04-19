# terraform-k3s-k8s Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-04-18

### Added
- `var.registry_mirrors` (type `map(list(string))`, default `{ "docker.io" = ["https://mirror.gcr.io"] }`). The map is rendered into `/etc/rancher/k3s/registries.yaml` before the k3s systemd unit starts for the first time, so containerd reads the mirror list at startup and routes Docker Hub pulls through Google's public pull-through cache. Addresses observed `ImagePullBackOff` on `alpine:3.20`, `grafana/grafana:11.5.2`, and `kiwigrid/k8s-sidecar` due to residential-ISP TLS handshake timeouts against `registry-1.docker.io`. Set to `{}` to disable mirroring entirely (direct pulls). Operators with their own pull-through cache (Harbor, Zot, Sonatype Nexus) can add entries for `quay.io`, `ghcr.io`, etc. — no public mirrors exist for those registries. Ignored when `install_k3s = false` because containerd on an adopted cluster has already read its configuration.

## [0.3.0] - 2026-04-18

### Added
- `null_resource.k3s_install` now waits for `/run/flannel/subnet.env` to appear before returning, so downstream addon pods never catch the transient window after the node goes Ready but before flannel writes its CNI state. Removes the first-apply `FailedCreatePodSandBox: failed to load flannel 'subnet.env' file` churn. Gated on `var.cni == "flannel"` — when the operator brings their own CNI (`cni = "none"`), the step is skipped.

### Breaking
- This release is published as part of the **major v0.3.0** bump: the module no longer ships the addon layer (Traefik, cert-manager, Let's Encrypt issuers, kube-prometheus-stack, PodSecurity-labeled namespaces, demo ops StatefulSet). Those resources moved to the new `terraform-k8s-addons` sibling module and are consumed on top via `module "addons" { kubeconfig_path = module.k8s.kubeconfig_path ... }`. Variables `enable_traefik`, `enable_traefik_dashboard`, `enable_cert_manager`, `enable_monitoring`, `create_ops_workload`, `namespaces`, `namespace`, `namespace_pod_security_level`, `enable_namespace_limits`, `base_domain`, `letsencrypt_email`, `traefik_version`, `cert_manager_version`, `kube_prometheus_stack_version`, `ops_image`, `ops_storage_class_name` were removed; corresponding outputs (`grafana_credentials`, `ingress_class`, `traefik_dashboard_url`, `grafana_url`, `namespaces`, `ops_statefulset_name`, `traefik_enabled`, `cert_manager_enabled`, `monitoring_enabled`) move to `terraform-k8s-addons`. Migrating from v0.2.x: keep your cluster-shape inputs (SSH, CIDRs, `install_k3s`, `k3s_*`) as-is and add a `module "addons"` block with `kubeconfig_path = module.k8s.kubeconfig_path` + the addon flags that used to live on this module.

### Changed
- `kubeconfig_path` output now carries an explicit `depends_on = [null_resource.k3s_install, data.local_sensitive_file.kubeconfig]` so downstream consumers wait for the kubeconfig file to actually land on disk before making API calls — plan-time-known literal strings otherwise let the Terraform graph schedule addon-layer resources in parallel with the installer and they hit `connection refused`.
- `k3s_effective_disable` always includes `traefik` (no longer conditional on a nonexistent `enable_traefik` input); k3s's built-in Traefik would always conflict with the Helm-managed Traefik shipped by the addons module.

## [0.2.2] - 2026-04-18

### Fixed
- cert-manager `helm_release` now passes `commonLabels` under `global.` instead of at the root of the chart values. The chart's `values.schema.json` (v1.14+) only whitelists `commonLabels` under `$defs.helm-values.global.properties`, so a root-level value produced `Additional property commonLabels is not allowed` and failed the release at plan time. Our labels now reach the cert-manager objects as intended.

### Changed
- Traefik `helm_release` namespace aligned with the sibling `terraform-minikube-k8s`: `traefik` → `ingress-controller`. Matching namespaces across distributions means platform cheatsheets, NetworkPolicies, and docs can address the ingress controller uniformly.

## [0.2.1] - 2026-04-18

### Fixed
- `null_resource.k3s_install` remote-exec no longer races the API server during first apply. Previously the provisioner ran `kubectl wait --for=condition=Ready node --all` immediately after the installer returned, but `kubectl wait --all` does not wait for resources to *exist* — on a fresh install the node had not yet registered with the API server, so kubectl exited with `error: no matching resources found` and status 1, failing the provisioner and leaving the cluster running but unmanaged. The wait is now staged: (1) kubeconfig file appears, (2) at least one Node shows up in the API (polled with a 120s timeout), (3) `kubectl wait --for=condition=Ready` runs. Fixes single-phase apply on cold hosts.

## [0.2.0] - 2026-04-18

### Added
- `install_k3s` variable (default: `true`). Setting to `false` adopts a pre-installed k3s service on the target host: the installer and uninstaller are skipped, the module only fetches the kubeconfig and converges the platform layer. Cluster-shape variables become informational in this mode
- `kube_prometheus_stack_version` variable (default: `"70.0.0"`). Monitoring chart version is no longer hardcoded — consistent with `traefik_version` and `cert_manager_version`
- Second `validation` block on `letsencrypt_email` rejecting RFC-2606 reserved domains
- `lifecycle.precondition` on `helm_release.cluster_issuers` requiring `enable_traefik = true` (HTTP-01 solver template hardcodes ingress class `traefik`)
- `cluster_distribution` output (value: `"k3s"`) lets sibling-module consumers programmatically branch on which distribution is active without hardcoding the source path
- `base_domain` variable (default: `"localhost"`). Traefik dashboard and Grafana hostnames are now derived as `traefik.<base_domain>` and `grafana.<base_domain>` instead of hardcoded `*.localhost`. Also surfaces a new `traefik_dashboard_url` output.
- `ops_storage_class_name` variable pins the StorageClass used by the ops StatefulSet's PVC (default: `"local-path"`, matching k3s' built-in local-path-provisioner)
- Pod Security Standards labels (`enforce`/`audit`/`warn`) applied to every module-managed namespace via the new `namespace_pod_security_level` variable (default: `baseline`)
- Default `kubernetes_resource_quota_v1` (4/8 CPU requests/limits, 8Gi/16Gi memory, 50 pods) and `kubernetes_limit_range_v1` (100m/128Mi request, 500m/512Mi limit per container) applied to each module-managed namespace. Gated by the new `enable_namespace_limits` variable (default: `true`)
- `ops` StatefulSet now runs with a hardened `security_context`: `runAsNonRoot`, UID/GID 1000, `readOnlyRootFilesystem`, all Linux capabilities dropped, `RuntimeDefault` seccomp profile, and bounded `resources.requests`/`limits` — i.e., compatible with `restricted` PodSecurity

### Security
- Pre-commit hooks extended with `terraform_trivy` (HIGH/CRITICAL severity gate for Terraform security findings), `gitleaks` (commit-time secret scanning), `detect-private-key`, and `check-merge-conflict`

### Changed
- `random_password.grafana` now pins `keepers = { cluster = var.cluster_name }`. Prevents silent password rotation — and Grafana lockout — on provider-version upgrades
- `helm` provider requirement bumped from `~> 2.0` to `~> 2.17`

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
