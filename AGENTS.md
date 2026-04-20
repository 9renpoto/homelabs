# Repository Assistant Instructions

This file is the primary source of truth for AI assistant guidance in this repository.

## Build, test, and lint commands

This repository is centered on the **WSL2 + Docker Engine + NVIDIA GPU + NemoClaw + Ollama** path.

### Shell and repository checks

```sh
typos
gitleaks git --pre-commit --staged --no-banner .
```

### Ansible checks

```sh
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd ansible
ansible-lint
cd ..
```

There is no conventional unit-test suite in this repo; validation is centered on bootstrap scripts and Ansible lint.

## High-level architecture

- The deployment path is **WSL2 Ubuntu on a Windows host**, with GPU compute accessed via the native NVIDIA CUDA support in WSL2 (Windows NVIDIA driver shim at `/usr/lib/wsl/lib/`).
- The **bootstrap flow** starts in `ansible/`:
  - Tools are managed by Homebrew via `Brewfile` in the repository root. Run `brew bundle` to install dependencies.
  - The primary bootstrap playbook (`ansible/playbooks/wsl-nemoclaw-bootstrap.yml`, to be added) will install Docker Engine, nvidia-container-toolkit, and configure the NemoClaw + Ollama environment.
- **NemoClaw** is NVIDIA's secure agent runtime (OpenShell sandbox + TypeScript CLI plugin + Python Blueprint). It runs on Docker Engine. Ollama runs as a GPU-backed Docker container alongside it.

## Key conventions

- This repo is **public**. Never commit real secrets, credential files, backup archives, or snapshots.
- The primary local secret flow is **outside Git** under `/etc/openclaw/openclaw-core-secret/`, with one file per environment variable name.
- Although the deployment target is a single Windows-hosted homelab, prefer **production-adjacent technology choices**.
- Use **Ansible** for WSL2 bootstrap automation and **Docker** for container runtime.
- Use **Japanese for chat with the user**, but keep persistent engineering artifacts such as **commit messages, pull request text, and code review comments in English**.
