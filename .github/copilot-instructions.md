# Copilot Instructions

Use `AGENTS.md` at the repository root as the primary source of truth for this repository.

Key reminders mirrored here for Copilot sessions:

- The repo is centered on the **WSL2 + Docker Engine + NVIDIA GPU + NemoClaw + Ollama** path.
- Even though deployment targets one Windows-hosted homelab machine, prefer production-adjacent technology choices and infrastructure changes that can be validated in-repo.
- Use Ansible for WSL2 bootstrap automation and Docker for container runtime.
- Never commit secrets, tracked `.env` files, or backups.
- Runtime secret application is handled outside Git under a local `/etc/openclaw/openclaw-core-secret/` directory.
- Use Japanese in chat with the user, but write commit messages, pull request text, and review comments in English.

Common commands:

```sh
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd ansible
ansible-lint
cd ..
typos
```
