# Repository Assistant Instructions

This file is the primary source of truth for AI assistant guidance in this repository.

## Build, test, and lint commands

This repository is centered on the **WSL2 + Ansible + k3s + NVIDIA GPU + ArgoCD + NemoClaw + Ollama** path.

### Kubernetes / GitOps validation

Render the tracked Kustomize trees:

```sh
mkdir -p .tmp
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base > .tmp/openclaw-core.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/nvidia-device-plugin/base > .tmp/nvidia-device-plugin.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize gitops/argocd > .tmp/argocd-bootstrap.rendered.yaml
```

Validate rendered manifests and policies:

```sh
docker run --rm -v "$PWD:/work" -w /work ghcr.io/yannh/kubeconform:v0.6.7 -strict -summary -ignore-missing-schemas .tmp/openclaw-core.rendered.yaml .tmp/nvidia-device-plugin.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work openpolicyagent/conftest:v0.58.0 test --policy policy/kubernetes .tmp/openclaw-core.rendered.yaml .tmp/nvidia-device-plugin.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml gitops/argocd/applications/openclaw-bootstrap.yaml
```

For a focused single-target check:

```sh
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base
```

### Shell and repository checks

```sh
shellcheck infra/k8s/*.sh
typos
gitleaks git --pre-commit --staged --no-banner .
```

There is no conventional unit-test suite in this repo; validation is centered on manifest render/schema/policy checks and bootstrap scripts.

## High-level architecture

- The preferred deployment path is **single-node k3s inside WSL2 Ubuntu on a Windows host**, with GPU compute provided by the native NVIDIA CUDA support in WSL2 and the cluster bootstrapped by Ansible and ArgoCD from this public repo.
- A single consumer GPU (e.g. RTX 4060 Ti) cannot be passed through to a VMware Workstation Pro VM while Windows uses that GPU for display. WSL2 exposes the GPU through the Windows NVIDIA driver shim at `/usr/lib/wsl/lib/` without requiring passthrough.
- The **k3s/GitOps flow** starts in `ansible/` and `gitops/`:
  - Tools are managed by Homebrew via `Brewfile` in the repository root. Run `brew bundle` to install dependencies.
  - `ansible/playbooks/wsl-openclaw-bootstrap.yml` is the primary bootstrap entrypoint (to be added); it installs k3s, configures NVIDIA runtime support via the WSL2 shim, installs ArgoCD, applies the OpenClaw secret, and bootstraps GitOps.
  - `gitops/argocd/applications/openclaw-bootstrap.yaml` bootstraps ArgoCD against `gitops/argocd/`, which then creates the `openclaw-core` AppProject/Application and syncs `k8s/openclaw-core/base`.
- The **first Kubernetes milestone deploys NemoClaw with in-cluster GPU-backed Ollama**. `k8s/openclaw-core/base/deployment-ollama.yaml` runs Ollama with `runtimeClassName: nvidia`, persistent model storage, and a pre-pulled local model. `k8s/nvidia-device-plugin/base/` is reconciled separately through ArgoCD.

## Key conventions

- This repo is **public**. Never commit real secrets, Kubernetes `Secret` manifests with real values, VM-local secret files, backup archives, or snapshots.
- Docker Compose is not part of the active deployment model. Do not introduce Compose-first docs or workflows.
- Packer and VMware Workstation Pro are **no longer part of the active deployment path**. Do not reintroduce Packer workflows.
- The primary local secret flow is **outside Git** under `/etc/openclaw/openclaw-core-secret/`, with one file per environment variable name.
- The current milestone is intentionally **small**: NemoClaw plus the minimum Ollama path needed for the first chat. Redis, SearXNG, and Discord integration are follow-on work.
- Although the deployment target is a single Windows-hosted homelab, prefer **production-adjacent technology choices** and infrastructure changes that can be **rendered, validated, and regression-checked in-repo**.
- Use **Ansible** for WSL2 guest bootstrap automation, and **Kustomize + ArgoCD** for cluster application delivery.
- Use **Japanese for chat with the user**, but keep persistent engineering artifacts such as **commit messages, pull request text, and code review comments in English**.
