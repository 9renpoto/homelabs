# homelabs

Homelab infrastructure for bringing up **NemoClaw** inside **WSL2** on Windows, with GPU-backed inference via native NVIDIA CUDA support in WSL2. Uses official NemoClaw CLI with optional local Ollama for inference.

## Deployment path

- **Bootstrap:** Windows host → WSL2 Ubuntu (NVIDIA CUDA) → Ansible (Docker + NVIDIA) → NemoClaw CLI → OpenShell sandbox
- **Workload:** NemoClaw CLI with optional Ollama container for local inference (Privacy Router auto-selects)
- **Out of scope for the active path:** Kubernetes, ArgoCD, Redis, SearXNG, Discord integration

The repository remains public, so runtime secrets, kubeconfig, mutable state, and backups must stay outside Git.

## Why WSL2

A single NVIDIA GeForce GPU cannot be passed through to a VMware Workstation Pro VM while Windows is using that GPU for display. WSL2 solves this cleanly: Windows retains the GPU for the host display, and the WSL2 Ubuntu instance accesses CUDA through the Windows NVIDIA driver shim at `/usr/lib/wsl/lib/`.

## Technical Constraints

### GPU Architecture

- **GPU shared by Windows + WSL2:** The Windows NVIDIA driver manages allocation; WSL2 accesses the GPU through the CUDA shim at `/usr/lib/wsl/lib/`
- **Single GPU only:** No multiplexing isolation; design Ollama/NemoClaw for single-GPU workloads
- **No GPU passthrough required:** Unlike VMs, WSL2 provides direct CUDA access without nested virtualization overhead

### WSL2 Resource Limits

- **Memory:** Default 50% of host RAM. Adjust in `~/.wslconfig` on Windows if needed (e.g., for RTX 4090 with large models)
- **Disk:** VHDX backing store on Windows partition; ensure parent volume has ≥ 50GB free

### Networking

- **Container networking:** Docker containers on bridge/user network by default; use port binding or `--network host` to expose services to LAN
- **Secrets:** Stored outside Git in `/etc/openclaw/openclaw-core-secret/` (one file per environment variable)

## Repository layout

Primary bootstrap and delivery assets:

- `ansible/` — Docker + NVIDIA + NemoClaw bootstrap (playbook to be added)
- `ansible/roles/openclaw_secret/` — local secret directory management

## Windows host prerequisites

Install and prepare the following on the Windows host:

- WSL2 with Ubuntu 24.04 (enable with `wsl --install`)
- NVIDIA GPU drivers for Windows (WSL2 CUDA shim is included)
- Confirm `nvidia-smi` works inside WSL2 before bootstrapping

Enable systemd in WSL2 if not already active:

```sh
# Inside WSL2 Ubuntu
echo '[boot]' | sudo tee -a /etc/wsl.conf
echo 'systemd=true' | sudo tee -a /etc/wsl.conf
# Then restart WSL: wsl --shutdown from PowerShell
```

Verify NVIDIA CUDA is visible:

```sh
# Inside WSL2 Ubuntu
nvidia-smi
```

## Quick Start

Follow these 4 steps to get NemoClaw running on WSL2 with GPU support.

### Step 1: Prerequisites (One-time Setup)

**Windows Host:**
- WSL2 with Ubuntu 24.04: `wsl --install`
- NVIDIA GPU drivers (WSL2 CUDA shim included)

**Inside WSL2:**
```bash
# Enable systemd (if not already enabled)
echo '[boot]' | sudo tee -a /etc/wsl.conf
echo 'systemd=true' | sudo tee -a /etc/wsl.conf
# Restart: wsl --shutdown (from PowerShell)

# Verify GPU is visible
nvidia-smi
```

### Step 2: Bootstrap Docker + NVIDIA (Ansible)

Inside WSL2:

```bash
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
brew bundle
export LANG=C.UTF-8 LC_ALL=C.UTF-8
cd ansible && ansible-playbook playbooks/wsl-nemoclaw-bootstrap.yml && cd ..
```

**Result:** Docker daemon running, GPU visible inside containers.

### Step 3: Install NemoClaw CLI

```bash
# Install nvm (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
source ~/.bashrc

# Install Node.js 22.16+
nvm install 22.16
node --version

# Install NemoClaw CLI from source
npm install -g git+https://github.com/NVIDIA/NemoClaw.git
nemoclaw --version
```

### Step 4: Onboard and Connect

```bash
# Run interactive onboard wizard (select model, privacy policy, network policy)
nemoclaw onboard

# After onboard completes, connect to sandbox
nemoclaw <name> connect

# Inside sandbox, launch chat UI
openclaw tui

# Or send a message via CLI
openclaw agent --agent main -m "hello" --session-id test
```

That's it! NemoClaw CLI manages the OpenShell sandbox and inference routing.

## Optional: Local Ollama for Inference

By default, `nemoclaw onboard` configures inference routing. NemoClaw Privacy Router can use:
- Local Ollama (if available)
- NVIDIA Cloud API (Nemotron 3 hosted)
- OpenAI, Anthropic APIs

To run local Ollama for GPU-backed inference (requires 8GB+ VRAM):

```bash
# Pull Ollama image
docker pull ollama/ollama:0.1.0

# Start Ollama container (GPU enabled)
docker run -d --gpus all --name ollama \
  -v /var/lib/ollama:/root/.ollama \
  ollama/ollama:0.1.0

# Verify GPU access
docker exec ollama nvidia-smi

# NemoClaw onboard will auto-detect Ollama on localhost:11434
```

For more details, see [Ollama documentation](https://github.com/ollama/ollama).

## Local secret management

This repository uses external secret files instead of tracked `.env` files.

When runtime secrets are needed, create a local directory where **each file name is the environment variable name** and the file contents are the secret value:

```sh
sudo install -d -m 700 /etc/openclaw/openclaw-core-secret
sudo install -m 600 /dev/null /etc/openclaw/openclaw-core-secret/DISCORD_BOT_TOKEN
sudoedit /etc/openclaw/openclaw-core-secret/DISCORD_BOT_TOKEN
```

The Ansible playbook creates `/etc/openclaw/openclaw-core-secret` during bootstrap.

## Repository validation

```sh
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd ansible
ansible-lint
cd ..
typos
shellcheck ansible/**/*.sh 2>/dev/null || true
```

## Pre-Bootstrap Validation

Before running the Ansible playbook, verify your WSL2 environment meets requirements:

### Stage 1: Verify WSL2 systemd

```bash
# Inside WSL2 Ubuntu
systemctl is-system-running
# Expected: running
```

If systemd is not running, enable it in `/etc/wsl.conf`:

```ini
[boot]
systemd=true
```

Then restart WSL2 from PowerShell: `wsl --shutdown`

### Stage 2: Verify GPU Visibility

```bash
# Inside WSL2 Ubuntu
nvidia-smi
# Expected: GPU device listed (e.g., Tesla T4, RTX 4060 Ti)
```

### Stage 3: Verify Disk & Memory

```bash
# Inside WSL2
df -h | head -5              # Should show ≥ 10GB available on root
free -h | head -2            # Should show ≥ 8GB available memory
```

If resources are low, expand the WSL2 VHDX from Windows (`diskpart` commands) or adjust `%USERPROFILE%\.wslconfig`.

## Post-Bootstrap Verification

After both stages complete, verify the deployment:

### Verify Ansible Docker + NVIDIA Setup

```bash
docker --version
docker ps  # List running containers
docker exec ollama nvidia-smi  # (if Ollama is running)
```

### Verify NemoClaw CLI Setup

```bash
nemoclaw --version
nemoclaw list
nemoclaw my-assistant status
nemoclaw my-assistant logs --tail 20
```

### Verify GPU in OpenShell Sandbox

```bash
nemoclaw my-assistant connect
# Inside sandbox:
nvidia-smi  # GPU should be visible
```

## Optional: Ollama for Local Inference

If you want to use local Ollama models for inference instead of cloud APIs:

1. Ollama container is optionally started by Ansible (`ansible/roles/ollama/`)
2. NemoClaw Privacy Router auto-discovers Ollama and routes inference through it
3. To pull a model:

```bash
docker exec ollama ollama pull nemotron-mini
```

For advanced setup, refer to [Ollama documentation](https://github.com/ollama/ollama).

## Repository validation

## Contributing

PRs accepted.

## License

MIT © TBD
