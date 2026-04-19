# homelabs

Kubernetes-first homelab infrastructure for bringing up **NemoClaw + Ollama** on single-node k3s inside **WSL2** on Windows, with GPU-backed inference via the native NVIDIA CUDA support in WSL2 and the cluster bootstrapped by Ansible and ArgoCD from this public repository.

## Deployment path

- **Bootstrap:** Windows host → WSL2 Ubuntu (NVIDIA CUDA) → Ansible → Docker Engine → NemoClaw + Ollama
- **Workload:** NemoClaw CLI with GPU-backed Ollama (Docker コンテナ)
- **Out of scope for the active path:** Kubernetes, ArgoCD, Redis, SearXNG, Discord integration

The repository remains public, so runtime secrets, kubeconfig, mutable state, and backups must stay outside Git.

## Why WSL2

A single NVIDIA GeForce GPU cannot be passed through to a VMware Workstation Pro VM while Windows is using that GPU for display. WSL2 solves this cleanly: Windows retains the GPU for the host display, and the WSL2 Ubuntu instance accesses CUDA through the Windows NVIDIA driver shim at `/usr/lib/wsl/lib/`.

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

## Bootstrap NemoClaw

Clone the repository inside WSL2 and run the bootstrap playbook (playbook to be added):

```sh
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
brew bundle
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd ansible
ansible-playbook playbooks/wsl-nemoclaw-bootstrap.yml
cd ..
```

The bootstrap playbook will:

- install Docker Engine idempotently
- install nvidia-container-toolkit using the WSL2 CUDA shim
- verify that `nvidia-smi` is visible inside Docker
- start the Ollama and NemoClaw containers

## Local secret management

This repository uses external secret files instead of tracked `.env` files.

When runtime secrets are needed, create a local directory where **each file name is the environment variable name** and the file contents are the secret value:

```sh
sudo install -d -m 700 /etc/openclaw/openclaw-core-secret
sudo install -m 600 /dev/null /etc/openclaw/openclaw-core-secret/DISCORD_BOT_TOKEN
sudoedit /etc/openclaw/openclaw-core-secret/DISCORD_BOT_TOKEN
```

The bootstrap playbook looks for `/etc/openclaw/openclaw-core-secret` by default.

## Operator verification

After bootstrap:

```sh
docker ps
docker exec ollama nvidia-smi
docker exec ollama ollama list
```

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

## Contributing

PRs accepted.

## License

MIT © TBD
