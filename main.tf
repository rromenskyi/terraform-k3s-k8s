# Root module entrypoint — cluster bootstrap only.
#
# This module owns the distribution-specific concerns of provisioning k3s
# on a target host: SSH install via the official get.k3s.io installer,
# kubeconfig fetch, and structural exposition of the cluster API and
# certificates. The opinionated platform layer (Traefik / cert-manager /
# monitoring / namespaces / demo ops StatefulSet) lives in the sibling
# `terraform-k8s-addons` module and is consumed on top of this one —
# see the module README for composition examples.
#
# Resources are split across files:
# - cluster.tf  — k3s install over SSH + kubeconfig fetch
# - locals.tf   — common labels used in outputs
