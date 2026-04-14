# OpenClaw Homelabs Roadmap

This roadmap reflects the active direction of the repository today.

## Current direction

- Run OpenClaw core on single-node k3s inside the existing WSL2 Ubuntu instance.
- Bootstrap the host with Ansible.
- Deliver cluster resources with Kustomize and ArgoCD.
- Keep the repository public and keep secrets, kubeconfig, backups, and mutable state outside Git.

## Current scope

- `ansible/playbooks/wsl-openclaw-bootstrap.yml` is the primary bootstrap entrypoint.
- `gitops/argocd/` bootstraps ArgoCD from this repository.
- `k8s/openclaw-core/base/` deploys OpenClaw core and in-cluster Ollama.
- `k8s/nvidia-device-plugin/base/` provides GPU device discovery for Ollama.

## Working principles

- Prefer reproducible rebuild over routine backup or restore.
- Keep the deployed footprint small and focused on the first chat path.
- Use production-adjacent tools even for a single home-PC installation.
- Make infrastructure changes reviewable and validation-friendly from the repository.

## Current priorities

1. Keep the WSL2 -> k3s -> ArgoCD -> OpenClaw bootstrap path repeatable.
2. Keep the local secret-directory workflow for `openclaw-core-env` stable.
3. Keep render, schema, policy, and script checks aligned with the live bootstrap path.
4. Keep OpenClaw core and Ollama healthy on the GPU-backed k3s node.
5. Add optional components only when they help the active Kubernetes path.

## Deferred items

- Redis remains out of scope for the active path.
- SearXNG remains out of scope for the active path.
- Discord integration remains out of scope for the active path.
- Backup and restore remain operator-only helpers, not the primary operating model.

## Success state

- `openclaw-bootstrap`, `nvidia-device-plugin`, and `openclaw-core` are `Synced` and `Healthy`.
- `openclaw-system` contains healthy `ollama` and `openclaw` deployments.
- The repository can render and validate the bootstrap path before rollout.
