# Repository Assistant Instructions

This file is the primary source of truth for AI assistant guidance in this repository.

## Build, test, and lint commands

This repo has two active operating modes: a local Docker Compose stack for headless OpenClaw work, and a greenfield k3s/ArgoCD path for the current deployment target.

### Local Compose workflow

Prerequisites from `README.md`:

- `dotenvx`
- Docker / Docker Compose
- `data/CLAW.REZ`

Start or rebuild the full local stack:

```sh
dotenvx run -- docker compose up -d --build
```

Rebuild only the OpenClaw service after editing `openclaw/openclaw.managed.json`, `openclaw/workspace/AGENTS.md`, or `openclaw/workspace-smoke/AGENTS.md`:

```sh
dotenvx run -- docker compose up -d --build openclaw
```

Smoke-test one agent in the running container:

```sh
docker compose exec openclaw openclaw agent --local --agent smoke --thinking off --timeout 1200 --message "hello world" --json
```

### Lint and repository checks

Repository formatting/linting:

```sh
biome ci .
typos
hadolint openclaw/Dockerfile ollama/Dockerfile
gitleaks git --pre-commit --staged --no-banner .
```

The staged `gitleaks` command matches `lefthook.yaml`. GitHub Actions also runs Biome plus Super Linter.

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

For a focused single-target check, render just one tree:

```sh
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base
```

There is no conventional unit-test suite in this repo; targeted validation is done with Kustomize rendering, schema/policy checks, and the container smoke command above.

### Hyper-V host script tests

Run the Hyper-V PowerShell tests:

```powershell
pwsh -NoLogo -NoProfile -Command "if (-not (Get-Module -ListAvailable Pester)) { Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck }; Invoke-Pester -Path ./infra/hyperv/New-OpenClawK3sVm.Tests.ps1"
```

This suite mocks the Hyper-V cmdlets, so it validates script behavior without requiring an actual Hyper-V host.

## High-level architecture

- The repo intentionally keeps **two parallel paths**:
  - **Preferred deployment path:** single-node k3s inside a dedicated Ubuntu VM, bootstrapped with ArgoCD and reconciled from this public repo.
  - **Local/runtime path:** Docker Compose stack for headless OpenClaw with `openclaw`, `ollama`, `redis`, and `searxng`.
- The **k3s/GitOps flow** starts in `infra/`:
  - `infra/hyperv/` creates the VM.
  - `infra/cloud-init/openclaw-k3s-user-data.yaml` seeds the Ubuntu guest.
  - `infra/k8s/bootstrap-openclaw-vm.sh` orchestrates `install-k3s.sh`, `install-argocd.sh`, optional secret application, and `bootstrap-openclaw-gitops.sh`.
  - `gitops/argocd/applications/openclaw-bootstrap.yaml` bootstraps ArgoCD against `gitops/argocd/`, which then creates the `openclaw-core` AppProject/Application and syncs `k8s/openclaw-core/base`.
- The **first Kubernetes milestone deploys only OpenClaw core**. `k8s/openclaw-core/base/deployment-openclaw.yaml` mounts a PVC at `/home/node/.openclaw`, seeds `openclaw.json` from a ConfigMap on first boot, and reads runtime env from the optional `openclaw-core-env` secret.
- The **Compose/OpenClaw path** builds a thin wrapper image in `openclaw/`. The image adds `openclaw/openclaw.managed.json`, workspace `AGENTS.md` templates, `merge-managed-config.cjs`, and `entrypoint.sh` on top of the upstream OpenClaw image.
- On container startup, `openclaw/entrypoint.sh` merges source-controlled defaults into runtime state at `/home/node/.openclaw/openclaw.json` and copies workspace `AGENTS.md` templates into the runtime home. This preserves generated state while keeping repo-managed defaults declarative.

## Key conventions

- This repo is **public**. Never commit real secrets, decrypted `.env` files, `.env.keys`, Kubernetes `Secret` manifests, VM-local secret files such as `/etc/openclaw/openclaw-core.env`, backup archives, or snapshots.
- For the Compose/OpenClaw path, edit the **source-controlled templates**, not generated runtime state:
  - edit `openclaw/openclaw.managed.json`, not `state/openclaw/openclaw.json`
  - edit `openclaw/workspace/AGENTS.md` or `openclaw/workspace-smoke/AGENTS.md`, not the synced copies under `state/openclaw/**`
- Provider routing is **env-driven at startup**. The important knobs are `LOCAL_PRIMARY`, `OLLAMA_SYNC_FALLBACK`, `FALLBACK_GUARD`, and `ALT1_*` / `ALT2_*`. If routing behavior changes, update the managed config and env contract rather than hardcoding runtime state.
- The current k3s milestone is intentionally **smaller than the Compose stack**: Kubernetes manifests target OpenClaw core first and do not yet migrate Ollama, Redis, SearXNG, or Discord integration.
- The Kubernetes secret for runtime env is intentionally **optional**. Bootstrap scripts and manifests are designed so the first GitOps rollout can succeed before VM-local credentials are finalized.
- Although the deployment target is a single Windows-hosted homelab, prefer **production-adjacent technology choices** and infrastructure changes that can be **rendered, validated, and regression-checked in-repo** like an IaC/CDK workflow.
- Split IaC choices by layer: **PowerShell + Hyper-V module** for VM construction on the Windows host, **cloud-init** for first-boot guest bootstrap, **Ansible** as the likely path for richer in-guest config management, and **Kustomize + ArgoCD** for cluster application delivery.
- Use **Japanese for chat with the user**, but keep persistent engineering artifacts such as **commit messages, pull request text, and code review comments in English**.
- Biome is the repo formatter/linter for tracked files, with JavaScript configured for double quotes in `biome.json`.
