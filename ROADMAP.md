# OpenClaw Homelabs Roadmap

This roadmap reflects the active direction of the repository today.

## Current direction

- Run NemoClaw + Ollama on single-node k3s inside WSL2 (Ubuntu) on Windows.
- Bootstrap WSL2 with Ansible and deliver cluster resources with Kustomize and ArgoCD.
- Use WSL2 native NVIDIA CUDA support for GPU-backed Ollama inference.
- Keep the repository public and keep secrets, kubeconfig, backups, and mutable state outside Git.

## Current scope

- `ansible/playbooks/wsl-openclaw-bootstrap.yml` will be the primary bootstrap entrypoint (to be added).
- `gitops/argocd/` bootstraps ArgoCD from this repository.
- `k8s/openclaw-core/base/` deploys NemoClaw and in-cluster Ollama (NemoClaw migration pending).
- `k8s/nvidia-device-plugin/base/` provides GPU device discovery for Ollama.

## Deployment path

```
Windows host
  └─ WSL2 Ubuntu (NVIDIA CUDA via Windows driver shim)
       └─ Ansible bootstrap
            └─ k3s
                 └─ ArgoCD (GitOps from this repo)
                      └─ NemoClaw + Ollama
```

## Working principles

- Prefer reproducible rebuild over routine backup or restore.
- Keep the deployed footprint small and focused on the first chat path.
- Use production-adjacent tools even for a single home-PC installation.
- Make infrastructure changes reviewable and validation-friendly from the repository.

## Current priorities

1. Implement Ansible bootstrap playbook for WSL2 (`wsl-openclaw-bootstrap.yml`).
2. Validate NVIDIA CUDA visibility inside WSL2 before treating the path as ready.
3. Migrate k8s manifests from OpenClaw to NemoClaw.
4. Keep the local secret-directory workflow for `openclaw-core-env` stable.
5. Keep render, schema, policy, and script checks aligned with the live bootstrap path.

## Deferred items

- Redis remains out of scope for the active path.
- SearXNG remains out of scope for the active path.
- Discord integration remains out of scope for the active path.
- Backup and restore remain operator-only helpers, not the primary operating model.

## Success state

- `openclaw-bootstrap`, `nvidia-device-plugin`, and `openclaw-core` are `Synced` and `Healthy`.
- `openclaw-system` contains healthy `ollama` and `nemoclaw` deployments.
- `nvidia-smi` is visible inside WSL2 and GPU is allocatable in k3s.
- The repository can render and validate the bootstrap path before rollout.
