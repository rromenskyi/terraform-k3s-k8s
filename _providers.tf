# Providers consume the fetched kubeconfig via `config_path`, which is lazy:
# the file does not have to exist at plan time, only when API calls are made.
# Inline host/cert attributes would force the data source to resolve during
# plan and break first-time bootstrap.

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}
