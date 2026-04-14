# Repository Assistant Instructions

This file is the primary source of truth for AI assistant guidance in this repository.

## Build, test, and lint commands

This repository is now centered on the **WSL2 + Ansible + k3s + NVIDIA GPU + ArgoCD + OpenClaw core** path.

### Kubernetes / GitOps validation

Render the two tracked Kustomize trees:

```sh
mkdir -p .tmp
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base > .tmp/openclaw-core.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize gitops/argocd > .tmp/argocd-bootstrap.rendered.yaml
```

Validate rendered manifests and policies:

```sh
docker run --rm -v "$PWD:/work" -w /work ghcr.io/yannh/kubeconform:v0.6.7 -strict -summary -ignore-missing-schemas .tmp/openclaw-core.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work openpolicyagent/conftest:v0.58.0 test --policy policy/kubernetes .tmp/openclaw-core.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml gitops/argocd/applications/openclaw-bootstrap.yaml
```

For a focused single-target check:

```sh
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base
```

### Shell and repository checks

```sh
shellcheck infra/k8s/*.sh
hadolint ollama/Dockerfile
typos
gitleaks git --pre-commit --staged --no-banner .
```

There is no conventional unit-test suite in this repo; validation is centered on manifest render/schema/policy checks and bootstrap scripts.

## High-level architecture

- The preferred deployment path is **single-node k3s inside the existing WSL2 Ubuntu instance**, with WSL/k3s bootstrap managed by Ansible and cluster delivery bootstrapped with ArgoCD from this public repo.
- The **k3s/GitOps flow** starts in `ansible/` and `gitops/`:
  - `ansible/playbooks/wsl-openclaw-bootstrap.yml` is the primary bootstrap entrypoint; it installs k3s, configures NVIDIA runtime support, installs ArgoCD, applies the optional OpenClaw secret, and bootstraps GitOps.
  - `ansible/playbooks/wsl-k3s-gpu.yml` remains available as a narrower NVIDIA runtime playbook.
  - `gitops/argocd/applications/openclaw-bootstrap.yaml` bootstraps ArgoCD against `gitops/argocd/`, which then creates the `openclaw-core` AppProject/Application and syncs `k8s/openclaw-core/base`.
- The **first Kubernetes milestone deploys OpenClaw core with in-cluster Ollama**. `k8s/openclaw-core/base/deployment-openclaw.yaml` mounts a PVC at `/home/node/.openclaw`, seeds `openclaw.json` from a ConfigMap on first boot, and reads runtime env from the optional `openclaw-core-env` secret. `k8s/openclaw-core/base/deployment-ollama.yaml` runs Ollama with `runtimeClassName: nvidia`, persistent model storage, and a pre-pulled local model. `k8s/nvidia-device-plugin/base/` is reconciled separately through ArgoCD.
- `searxng/` remains in the repo as a lower-priority future option, but it is not part of the active bootstrap workflow.

## Key conventions

- This repo is **public**. Never commit real secrets, Kubernetes `Secret` manifests with real values, VM-local secret files, backup archives, or snapshots.
- Docker Compose is **not** the active deployment model anymore. Do not reintroduce Compose-first docs or workflows.
- The primary local secret flow is **outside Git** under `/etc/openclaw/openclaw-core-secret/`, with one file per environment variable name.
- The Kubernetes secret for runtime env is intentionally **optional** so the first GitOps rollout can succeed before credentials are finalized.
- The current milestone is intentionally **small**: OpenClaw core plus the minimum Ollama path needed for the first chat. Redis, SearXNG, and Discord integration are follow-on work.
- Although the deployment target is a single Windows-hosted homelab, prefer **production-adjacent technology choices** and infrastructure changes that can be **rendered, validated, and regression-checked in-repo**.
- Use **Ansible** for WSL/k3s bootstrap automation and **Kustomize + ArgoCD** for cluster application delivery.
- Use **Japanese for chat with the user**, but keep persistent engineering artifacts such as **commit messages, pull request text, and code review comments in English**.
