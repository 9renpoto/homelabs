# Copilot Instructions

Use `AGENTS.md` at the repository root as the primary source of truth for this repository.

Key reminders mirrored here for Copilot sessions:

- The repo is centered on the preferred single-node k3s + ArgoCD deployment path.
- Even though deployment targets one Windows-hosted homelab machine, prefer production-adjacent technology choices and infrastructure changes that can be validated in-repo.
- Use Ansible for WSL/k3s bootstrap automation and Kustomize + ArgoCD for cluster delivery.
- Never commit secrets, tracked `.env` files, Kubernetes `Secret` manifests with real values, VM-local secret files, backups, or snapshots.
- Runtime secret application is handled outside Git with `infra/k8s/apply-openclaw-core-secret.sh` and a local `/etc/openclaw/openclaw-core-secret/` directory.
- `ollama/` and `searxng/` remain in-repo as future options, but they are not part of the active bootstrap path.
- Use Japanese in chat with the user, but write commit messages, pull request text, and review comments in English.

Common commands:

```sh
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize gitops/argocd
docker run --rm -v "$PWD:/work" -w /work ghcr.io/yannh/kubeconform:v0.6.7 -strict -summary -ignore-missing-schemas .tmp/openclaw-core.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work openpolicyagent/conftest:v0.58.0 test --policy policy/kubernetes .tmp/openclaw-core.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml gitops/argocd/applications/openclaw-bootstrap.yaml
shellcheck infra/k8s/*.sh
hadolint ollama/Dockerfile
```
