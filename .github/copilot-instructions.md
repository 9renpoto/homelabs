# Copilot Instructions

Use `AGENTS.md` at the repository root as the primary source of truth for this repository.

Key reminders mirrored here for Copilot sessions:

- The repo has two parallel tracks: the preferred single-node k3s + ArgoCD deployment path, and a Docker Compose path for local headless OpenClaw work.
- For OpenClaw config changes, edit source-controlled templates under `openclaw/`, not generated files under `state/openclaw/`.
- Never commit secrets, decrypted `.env` files, `.env.keys`, Kubernetes `Secret` manifests, VM-local secret files, backups, or snapshots.
- Provider routing is controlled by env vars such as `LOCAL_PRIMARY`, `OLLAMA_SYNC_FALLBACK`, `FALLBACK_GUARD`, and `ALT1_*` / `ALT2_*`.

Common commands:

```sh
dotenvx run -- docker compose up -d --build
dotenvx run -- docker compose up -d --build openclaw
docker compose exec openclaw openclaw agent --local --agent smoke --thinking off --timeout 1200 --message "hello world" --json
biome ci .
typos
hadolint openclaw/Dockerfile ollama/Dockerfile
gitleaks git --pre-commit --staged --no-banner .
```

Focused Kubernetes validation:

```sh
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base
```
