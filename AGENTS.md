# Repository Assistant Instructions

This file is the primary source of truth for AI assistant guidance in this repository.

## Build, test, and lint commands

This repository is centered on the **WSL2 + Docker Engine + NVIDIA GPU + NemoClaw + Ollama** path.

## High-level architecture

- The deployment path is **WSL2 Ubuntu on a Windows host**, with GPU compute accessed via the native NVIDIA CUDA support in WSL2 (Windows NVIDIA driver shim at `/usr/lib/wsl/lib/`).
- A single consumer GPU (e.g. RTX 4060 Ti) cannot be passed through to a VMware VM while Windows uses that GPU for display. WSL2 exposes the GPU without requiring passthrough.
- The **bootstrap flow** is simple:
  - Tools and runtime dependencies are managed by Homebrew via `Brewfile` in the repository root. Run `brew bundle` to install all packages (docker, containerd, nvidia-container-toolkit, build tools).
  - Setup script `infra/bootstrap.sh` handles daemon configuration (docker group, daemon.json, systemd).
- **NemoClaw** is NVIDIA's secure agent runtime (OpenShell sandbox + TypeScript CLI plugin + Python Blueprint). It runs on Docker Engine, not Kubernetes. Ollama runs as a GPU-backed Docker container alongside it.

## Key conventions

- This repo is **public**. Never commit real secrets, credential files, backup archives, or snapshots.
- Docker Compose and Kubernetes are not part of the active deployment model.
- The primary local secret flow is **outside Git** under `/etc/openclaw/openclaw-core-secret/`, with one file per environment variable name.
- The current milestone is intentionally **small**: NemoClaw plus the minimum Ollama path needed for the first chat. Redis, SearXNG, and Discord integration are follow-on work.
- Although the deployment target is a single Windows-hosted homelab, prefer **production-adjacent technology choices**.
- Use **Homebrew** for package management and **shell scripts** for setup automation on WSL2.
- Use **Japanese for chat with the user**, but keep persistent engineering artifacts such as **commit messages, pull request text, and code review comments in English**.
