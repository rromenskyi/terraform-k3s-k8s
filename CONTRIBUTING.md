# Contributing

Thank you for wanting to improve this module!

## How to contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Install pre-commit hooks (`pip install pre-commit && pre-commit install`)
4. Make your changes
5. Run `pre-commit run -a` (or let CI do it)
6. Ensure all checks pass
7. Open a Pull Request

## What we welcome

- Multi-server / HA k3s bootstrap
- k3d support (in a separate module or as an opt-in bootstrap path)
- Extraction of the shared platform layer into a dedicated module consumed by both `terraform-minikube-k8s` and `terraform-k3s-k8s`
- New examples
- Documentation improvements
- Additional useful Helm charts
- Bug fixes

## Repository name

This repository is `terraform-k3s-k8s`.

---

Made for local Kubernetes development on k3s.
