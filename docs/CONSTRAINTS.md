# WSL2 / Windows / GPU Constraints

This document outlines the technical constraints and prerequisites for running NemoClaw + Ollama on WSL2 with NVIDIA GPU support.

## GPU Access Architecture

### Why WSL2 Instead of VMware

A single NVIDIA consumer GPU (e.g., RTX 4060 Ti) **cannot be passed through to a VMware Workstation Pro VM while Windows is using that GPU for display**. WSL2 solves this by:

- **Windows host retains GPU for display output** (driver manages allocation)
- **WSL2 Ubuntu accesses CUDA through the Windows NVIDIA driver shim** at `/usr/lib/wsl/lib/`
- **No GPU passthrough required** — both Windows and WSL2 can access the GPU simultaneously

### GPU Visibility Path

```
Windows NVIDIA GPU Driver
    ↓
NVIDIA WSL shim at /usr/lib/wsl/lib/
    ↓
WSL2 Ubuntu nvidia-smi / CUDA libraries
    ↓
Docker Engine (via nvidia-container-toolkit)
    ↓
Ollama container (GPU-accelerated inference)
```

## WSL2 Prerequisites

### Host System (Windows)

- **NVIDIA GPU driver installed** (Windows host driver, not WSL2-specific)
  - Verify: Open PowerShell on Windows host → `nvidia-smi` should show GPU
- **WSL2 installed** (Windows feature enabled)
  - Verify: `wsl --version` from PowerShell
- **WSL2 distribution: Ubuntu 24.04**
  - Verify: Inside WSL2 → `lsb_release -a`

### Inside WSL2 (Ubuntu)

#### Systemd (Required)

NemoClaw and Ollama may depend on systemd for service management. Verify/enable:

```bash
# Inside WSL2
# Check if systemd is running
systemctl is-system-running

# If not enabled, add to /etc/wsl.conf (edit from Windows):
# [boot]
# systemd=true
# Then: wsl --shutdown (from PowerShell), then reconnect to WSL2
```

#### NVIDIA CUDA (Verification)

```bash
# Inside WSL2, verify GPU visibility
nvidia-smi

# Expected output: GPU listed with VRAM, temperature
# If error: GPU driver issue on Windows host or WSL2 driver mismatch
```

#### Docker Engine (Not Yet Installed)

Docker Engine will be installed by the Ansible role `docker_engine`. Ensure:

- No conflicting container runtime (podman, etc.) pre-installed
- Sufficient disk space in WSL2 volume (`df -h` should show > 10GB available)

## Constraints

### GPU

- **No NVIDIA Docker plugin pull.** The NVIDIA container runtime is configured via Docker daemon config, not through a plugin.
- **Single GPU shared by Windows + WSL2.** No GPU multiplexing isolation; design Ollama/NemoClaw for single-GPU.
- **CUDA Compute Capability depends on GPU model.** Ollama will gracefully fall back to CPU if GPU is incompatible, but performance degrades.

### Memory & Disk

- **WSL2 memory limit (default 50% of host).** If host has 32GB RAM, WSL2 can use up to 16GB. Adjust in `~/.wslconfig` on Windows if needed.
- **Disk backing store** is a VHDX file on Windows; ensure parent volume has > 50GB free.

### Networking

- **Ollama + NemoClaw run in Docker containers on bridge/user network.** For LAN access (homelab scenario), use host network or port binding.
- **localhost access only by default.** To expose to other LAN machines, bind Docker ports to `0.0.0.0`.

### Secrets

- **Secrets are stored outside Git** in `/etc/openclaw/openclaw-core-secret/` (one file per env var).
- **No `~/.env` files committed.** The Ansible role `openclaw_secret` creates the directory; operator populates it.

## Success Criteria (Phase 1)

Before proceeding to Phase 2, verify:

1. ✓ `systemctl is-system-running` returns `running` inside WSL2
2. ✓ `nvidia-smi` shows GPU on Windows host **and** inside WSL2
3. ✓ WSL2 has ≥ 10GB free disk space (`df -h`)
4. ✓ WSL2 has ≥ 8GB available memory (check with `free -h`)

## References

- [NVIDIA Docker Container Toolkit - WSL2](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)
- [WSL2 Advanced Settings](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
- [NemoClaw Documentation](https://github.com/NVIDIA/nemoclaw) (when available)
- [Ollama Documentation](https://github.com/ollama/ollama)
