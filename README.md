# homelabs

NemoClaw + OpenShell sandbox on WSL2 Ubuntu with GPU-backed inference via NVIDIA CUDA. Bootstrapped with Ansible, Docker rootless mode, and optional Ollama container.

## Prerequisites

- **Windows Host:** WSL2 with Ubuntu 24.04, NVIDIA GPU driver installed
- **Inside WSL2:** Systemd enabled, `nvidia-smi` working, ≥ 10GB disk + 8GB RAM
- **Local setup:** `brew bundle` installs Docker rootless, Homebrew on WSL2

## Bootstrap

```bash
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
brew bundle
# Follow infra/install-nemoclaw.sh or use: nemoclaw onboard
```

For details, see [NemoClaw CLI docs](https://github.com/NVIDIA/NemoClaw).

## Secrets

External secret files stored at `/etc/openclaw/openclaw-core-secret/` (not Git-tracked). One file per environment variable.

## Validation

```sh
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd ansible && ansible-lint && cd ..
typos
```

## Contributing

PRs accepted.

## License

MIT © TBD
