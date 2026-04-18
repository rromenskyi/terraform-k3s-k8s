# terraform-k3s-k8s Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
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
