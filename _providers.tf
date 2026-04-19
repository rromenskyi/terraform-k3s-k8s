# After the addon layer was extracted into the sibling `terraform-k8s-addons`
# module, this module no longer creates any Kubernetes or Helm resources —
# it only runs an SSH `null_resource` installer and reads the kubeconfig
# file with `local_sensitive_file`. Neither needs the kubernetes/helm
# providers, so they are no longer declared here. The consumer (typically
# `terraform-k8s-addons`) configures those providers using `kubeconfig_path`
# from this module's outputs.
