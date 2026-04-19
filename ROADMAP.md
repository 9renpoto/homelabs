# OpenClaw Homelabs Roadmap

This roadmap reflects the active direction of the repository today.

## Current direction

- Run NemoClaw + Ollama on Docker Engine inside WSL2 (Ubuntu) on Windows.
- Bootstrap WSL2 with Ansible.
- Use WSL2 native NVIDIA CUDA support for GPU-backed Ollama inference.
- Keep the repository public and keep secrets, kubeconfig, backups, and mutable state outside Git.

## Current scope

- `ansible/playbooks/wsl-nemoclaw-bootstrap.yml` will be the primary bootstrap entrypoint (to be added).
- `ansible/roles/` will contain Docker Engine, nvidia-container-toolkit, and NemoClaw roles (to be added).

## Deployment path

```
Windows host
  └─ WSL2 Ubuntu (NVIDIA CUDA via Windows driver shim)
       └─ Ansible bootstrap
            └─ Docker Engine + nvidia-container-toolkit
                 └─ NemoClaw + Ollama (GPU)
```

## Working principles

- Prefer reproducible rebuild over routine backup or restore.
- Keep the deployed footprint small and focused on the first chat path.
- Use production-adjacent tools even for a single home-PC installation.
- Make infrastructure changes reviewable and validation-friendly from the repository.

## Current priorities

1. Implement Ansible bootstrap playbook for WSL2 (`wsl-nemoclaw-bootstrap.yml`).
2. Validate NVIDIA CUDA visibility inside WSL2 Docker before treating the path as ready.
3. Implement Ansible roles: `docker_engine`, `nvidia_docker`, `nemoclaw`.

## Deferred items

- Redis remains out of scope for the active path.
- SearXNG remains out of scope for the active path.
- Discord integration remains out of scope for the active path.
- Backup and restore remain operator-only helpers, not the primary operating model.

## Success state

- `nvidia-smi` is visible inside a Docker container in WSL2.
- Ollama starts with GPU access and responds to inference requests.
- NemoClaw CLI connects to Ollama and the first chat succeeds.
