# homelabs

Docker configuration for running OpenClaw (a Captain Claw reimplementation) in a headless setup on macOS, with a path toward Linux hosting.

## Roadmap

- See [ROADMAP.md](./ROADMAP.md) for the phased plan from local macOS validation to secure Ubuntu deployment.

## Experimental k3s bootstrap

This repository includes a greenfield path for running **OpenClaw core on single-node k3s** inside WSL2.

The current target is a **single home-PC deployment using the existing WSL2 Ubuntu instance**.
A separate environment is not part of the baseline design.

Even with that small physical footprint, the repository is also used for **technology validation with production-adjacent building blocks**. Prefer configurations and workflows that stay close to real production operating models rather than home-lab-only shortcuts.

Current IaC direction by layer:

- **WSL2 layer:** existing Ubuntu instance on Windows (Hyper-V Pro/dedicated machine is a future option)
- **Guest configuration layer:** shell scripts now, with Ansible as the likely next step when configuration management grows
- **Cluster application layer:** Kustomize + ArgoCD

Current first milestone:

- install k3s and ArgoCD inside the WSL2 Ubuntu instance
- deploy the initial OpenClaw core workload from this public repository
- keep secrets and runtime-only data outside Git
- make scrap-and-rebuild reproducible enough that backup automation can stay lower priority for now
- keep infrastructure changes reviewable and testable from the repository before applying them

Current scope intentionally excludes:

- Ollama (k3s path — GPU device plugin is a follow-on phase)
- Redis
- SearXNG
- Discord integration

Bootstrap assets:

- `infra/k8s/bootstrap-openclaw-wsl.sh`
- `infra/k8s/install-k3s.sh`
- `infra/k8s/install-argocd.sh`
- `infra/k8s/bootstrap-openclaw-gitops.sh`
- `gitops/argocd/kustomization.yaml`
- `gitops/argocd/projects/openclaw-core.yaml`
- `gitops/argocd/applications/openclaw-bootstrap.yaml`
- `k8s/openclaw-core/base/`
- `gitops/argocd/applications/openclaw-core.yaml`

These files are the starting point for a Kubernetes-native deployment and do not yet migrate the existing Docker Compose layout.
They should also remain suitable for fast repository-driven validation, so infrastructure work can be iterated with a feedback loop closer to CDK-style IaC development.

One-time bootstrap flow after ArgoCD is installed:

Run this from a clone of this repository inside WSL2:

```sh
./infra/k8s/bootstrap-openclaw-gitops.sh
```

After that, ArgoCD should reconcile:

- `gitops/argocd/projects/openclaw-core.yaml`
- `gitops/argocd/applications/openclaw-core.yaml`
- `k8s/openclaw-core/base/`

### Windows host prerequisites

The k3s bootstrap scripts run inside the WSL2 Ubuntu environment.
The only Windows-side requirement is [WSL2](https://learn.microsoft.com/windows/wsl/install) with an Ubuntu distribution.

#### 1. Enable WSL2 and install Ubuntu

From an elevated PowerShell session:

```powershell
wsl --install
# Restart when prompted, then Ubuntu will launch and ask for a username/password
```

If WSL is already installed but Ubuntu is not:

```powershell
wsl --install -d Ubuntu
```

#### 2. Enable systemd (required for k3s)

Inside the Ubuntu WSL2 terminal, create or update `/etc/wsl.conf`:

```sh
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF
```

Then restart the instance from PowerShell:

```powershell
wsl --shutdown
wsl
```

Verify:

```sh
systemctl is-system-running
```

#### 3. Clone this repository inside WSL2

```sh
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
```

#### 4. Run the bootstrap

```sh
sudo KUBECONFIG_USER="${USER}" ./infra/k8s/bootstrap-openclaw-wsl.sh
kubectl get nodes
kubectl get pods -A
```

---

### WSL2 to OpenClaw runbook

The first milestone is to make the following path repeatable:

1. install k3s inside WSL2
2. install ArgoCD
3. inject runtime secrets from a local file
4. apply the one-time bootstrap `Application`
5. confirm that `openclaw` becomes healthy in `openclaw-system`

The default operating model is:

- one WSL2 Ubuntu instance for the homelab environment
- no separate staging environment in the initial design
- rebuild from these repo-managed assets when needed

#### 1. Bootstrap k3s and ArgoCD

Run from a clone of this repository inside WSL2:

```sh
sudo KUBECONFIG_USER="${USER}" ./infra/k8s/bootstrap-openclaw-wsl.sh
kubectl get nodes
kubectl get pods -A
```

This wrapper runs:

- `infra/k8s/install-k3s.sh`
- `infra/k8s/install-argocd.sh`
- `infra/k8s/apply-openclaw-core-secret.sh` when `/etc/openclaw/openclaw-core.env` already exists
- `infra/k8s/bootstrap-openclaw-gitops.sh`

The bootstrap flow still works without the secret file because the `openclaw` Deployment treats that secret as optional.

`install-k3s.sh` also copies `/etc/rancher/k3s/k3s.yaml` into `${HOME}/.kube/config` for the selected operator user.

#### 2. Inject runtime secrets locally

This repository stays public, so real runtime values must be created locally and applied from WSL2.

```sh
sudo install -d -m 700 /etc/openclaw
sudo install -m 600 /dev/null /etc/openclaw/openclaw-core.env
sudoedit /etc/openclaw/openclaw-core.env
./infra/k8s/apply-openclaw-core-secret.sh /etc/openclaw/openclaw-core.env
kubectl -n openclaw-system get secret openclaw-core-env
```

The `openclaw` Deployment treats this secret as optional, so bootstrap can still proceed before every runtime value is finalized.

#### 3. Bootstrap GitOps

Apply the one-time bootstrap `Application`:

```sh
./infra/k8s/bootstrap-openclaw-gitops.sh
```

Expected result:

- `openclaw-bootstrap` syncs `gitops/argocd`
- ArgoCD creates the `openclaw-core` AppProject and Application
- `openclaw-core` syncs `k8s/openclaw-core/base`

#### 4. Verify the first OpenClaw rollout

Use these checks in order:

```sh
kubectl -n argocd get applications
kubectl -n openclaw-system get all
kubectl -n openclaw-system get pvc
kubectl -n openclaw-system rollout status deployment/openclaw
kubectl -n openclaw-system logs deployment/openclaw --tail=100
```

Minimum success criteria for the first milestone:

- `openclaw-bootstrap` is `Synced` and `Healthy`
- `openclaw-core` is `Synced` and `Healthy`
- namespace `openclaw-system` exists
- PVC `openclaw-home` is bound
- Deployment `openclaw` completes rollout

#### 5. Basic maintenance checks

After the cluster is up, use these commands as the first-line operator checks:

```sh
kubectl get nodes
kubectl -n argocd get applications
kubectl -n openclaw-system get pods,svc,ingress,pvc
kubectl -n openclaw-system describe deployment openclaw
```

#### 6. Lower-priority follow-up: backup and restore

Backup and restore remain important, but they are not the primary success condition for the first bootstrap milestone. The current priority is reproducible scrap-and-rebuild for a single home-PC installation.

When you are ready to capture runtime state, use:

```sh
./infra/k8s/backup-openclaw-core-pvc.sh ./openclaw-home-backup.tgz
```

When you are intentionally restoring onto a prepared PVC, use:

```sh
./infra/k8s/restore-openclaw-core-pvc.sh ./openclaw-home-backup.tgz
```

Also keep these outside Git and in restricted storage:

- `/etc/openclaw/openclaw-core.env`
- `/etc/rancher/k3s/k3s.yaml`
- any exported backup archives

### k3s secret and backup policy

This repository stays public, so **runtime secrets and backup artifacts must stay outside Git**.

Rules for the k3s bootstrap path:

- never commit Kubernetes `Secret` manifests
- never commit decrypted `.env` files
- never commit backup archives
- keep runtime secret material in WSL2 with root-readable permissions only
- use Git for declarative manifests, and use local files plus external backup storage for runtime-only data

The runbook above shows the operator flow. The core rule set remains:

Recommended secret injection flow in WSL2:

```sh
sudo install -d -m 700 /etc/openclaw
sudo install -m 600 /dev/null /etc/openclaw/openclaw-core.env
sudoedit /etc/openclaw/openclaw-core.env
./infra/k8s/apply-openclaw-core-secret.sh /etc/openclaw/openclaw-core.env
```

Current runtime secret target:

- namespace: `openclaw-system`
- secret name: `openclaw-core-env`

The `openclaw` Deployment references that secret as an **optional** `envFrom` source, so the first bootstrap can succeed before any real credentials are injected.

Recommended backup scope once the first bootstrap path is stable:

1. Git-managed manifests in this repository
2. Local secret files such as `/etc/openclaw/openclaw-core.env`
3. PVC contents for `openclaw-home`
4. k3s admin material stored locally and copied to restricted external storage

PVC helper scripts:

```sh
./infra/k8s/backup-openclaw-core-pvc.sh ./openclaw-home-backup.tgz
./infra/k8s/restore-openclaw-core-pvc.sh ./openclaw-home-backup.tgz
```

Restore is intentionally an operator action. Use it only against a fresh or intentionally prepared PVC.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [dotenvx](https://dotenvx.com/) (`brew install dotenvx/brew/dotenvx`)
- OpenClaw game data (`CLAW.REZ`) — obtain from the original Captain Claw disc or digital release

## Install

```sh
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
```

### Environment variables (Discord)

Manage Discord secrets with `dotenvx`:

```sh
cp .env.example .env
```

Then edit `.env` and set:

- `DISCORD_BOT_TOKEN`
- `GEMINI_API_KEY` (planner role)
- `GEMINI_MODEL` (default: `gemini-2.5-flash-lite`)
- `OLLAMA_MODEL` (worker role, default: `qwen2.5:0.5b`)
- `LOCAL_PRIMARY` (`0`: Gemini primary, `1`: Ollama primary)
- `OLLAMA_SYNC_FALLBACK` (`0`: disable Ollama in sync fallback chain, `1`: enable)
- `FALLBACK_GUARD` (`1`: auto-fill fallback if empty, `0`: disable guard)
- `ALT1_*` / `ALT2_*` (optional extra fallback providers)
- `REDIS_URL` (default: `redis://redis:6379`)
- `REDIS_CACHE_TTL_SEC` (default: `3600`)
- `REDIS_CACHE_PREFIX` (default: `openclaw:prompt-cache`)

OpenClaw native Discord channel is enabled automatically when `DISCORD_BOT_TOKEN` is present.

Encrypt `.env` before committing:

```sh
dotenvx encrypt
```

Rules:

- `.env` can be committed only after `dotenvx encrypt`
- `.env.keys` must stay local and must never be committed

## Usage

### Place game data

Create a `data/` directory and copy `CLAW.REZ` into it:

```sh
mkdir -p data
cp /path/to/CLAW.REZ data/
```

### Start (Headless)

Build and run all services (`openclaw`, `ollama`, `redis`):

```sh
dotenvx run -- docker compose up --build
```

### SearXNG local search API

This repository includes a local [SearXNG](https://github.com/searxng/searxng) service for search API fan-out and quota distribution.

Start services:

```sh
dotenvx run -- docker compose up -d --build
```

Verify SearXNG health from host:

```sh
docker compose port searxng 8080
PORT=$(docker compose port searxng 8080 | awk -F: '{print $NF}')
curl -sS "http://localhost:${PORT}/search?q=homelabs&format=json" | head
```

If you run behind a reverse proxy, set `SEARXNG_BASE_URL` in `.env`.

### Ollama setup for OpenClaw

OpenClaw runtime defaults are managed declaratively in:

- `openclaw/openclaw.managed.json`

At container startup, this file is merged into `state/openclaw/openclaw.json`.
That keeps source-controlled defaults while preserving runtime-generated fields.

Apply current declarative config:

```sh
dotenvx run -- docker compose up -d
```

If you update `openclaw/openclaw.managed.json`, rebuild `openclaw` to apply changes:

```sh
dotenvx run -- docker compose up -d --build openclaw
```

### Workspace AGENTS.md (reproducible)

For reproducible agent behavior, workspace `AGENTS.md` files are source-controlled as templates:

- `openclaw/workspace/AGENTS.md`
- `openclaw/workspace-smoke/AGENTS.md`

At container startup, these files are synced into runtime state paths:

- `state/openclaw/workspace/AGENTS.md`
- `state/openclaw/workspace-smoke/AGENTS.md`

This keeps runtime state deterministic without committing the whole `state/` directory.

### Duplicate Question Cache

OpenClaw currently applies request dedupe in gateway memory (idempotency-based, short-lived), and this repository does not expose a native Redis cache backend setting for that path.

To reduce repeated answers for the same user question, `AGENTS.md` templates include a practical cache policy:

- Store prompt fingerprints in `memory/prompt-cache.json`
- Reuse/summarize previous answer when the same normalized question is repeated within 1 hour
- Skip heavy tool calls on cache hits
- Keep cache bounded to 500 entries

If the user explicitly asks to refresh/re-run, bypass cache once and update the entry.

### Redis (infrastructure for middleware rollout)

This repository now includes a local Redis service to prepare middleware-based caching and state management.

Start all services with Redis:

```sh
dotenvx run -- docker compose up -d --build
```

Verify Redis health:

```sh
docker compose exec redis redis-cli ping
```

Expected output:

```txt
PONG
```

Current status:

- Redis is provisioned at infrastructure level (`redis:6379`).
- Prompt dedupe policy is still file-based (`memory/prompt-cache.json`) until middleware wiring is added.
- Next step is introducing a middleware layer that reads/writes dedupe keys in Redis using `REDIS_URL`, `REDIS_CACHE_TTL_SEC`, and `REDIS_CACHE_PREFIX`.

### Local-first multi-provider routing

This repository supports configurable routing with optional cloud fallbacks:

- Primary model: `google/${GEMINI_MODEL}` when `LOCAL_PRIMARY=0` and `GEMINI_API_KEY` is set
- Primary model: `ollama/${OLLAMA_MODEL}` when `LOCAL_PRIMARY=1` or `GEMINI_API_KEY` is unset
- Fallback #1: the other side (`ollama/*` or `google/*`) depending on primary
- Fallback #2 and #3: optional `ALT1_*` / `ALT2_*` provider slots

At startup, `openclaw` applies this behavior automatically:

- when `LOCAL_PRIMARY=0` and Gemini key exists, Gemini is primary and Ollama is fallback
- when `LOCAL_PRIMARY=1`, Ollama is primary and Gemini is fallback
- when `LOCAL_PRIMARY=0`, set `OLLAMA_SYNC_FALLBACK=0` to keep Ollama for async/subagent use only
- each `ALTn_*` slot is appended when all required values are present:
	- `ALTn_PROVIDER_ID`
	- `ALTn_PROVIDER_API`
	- `ALTn_BASE_URL`
	- `ALTn_API_KEY`
	- `ALTn_MODEL`

This lets you combine multiple free tiers and switch routing strategy without editing runtime state.

If local responses are slow or timing out, use `LOCAL_PRIMARY=0` (Gemini primary) and keep Ollama as fallback until local provider behavior is stable.

Example (`ALT1_*` with OpenAI-compatible endpoint such as OpenRouter):

```env
ALT1_PROVIDER_ID=openrouter
ALT1_PROVIDER_API=openai
ALT1_BASE_URL=https://openrouter.ai/api/v1
ALT1_API_KEY=...
ALT1_MODEL=meta-llama/llama-3.1-8b-instruct:free
```

### Free-tier stop avoidance profile

When a free-tier provider hits quota/rate limits, OpenClaw can stop if the fallback list ends up empty.
To avoid that, keep `FALLBACK_GUARD=1` (default in this repository).

Recommended profile:

- `LOCAL_PRIMARY=0` (Gemini first for normal latency)
- `OLLAMA_SYNC_FALLBACK=0` (do not use local fallback unless needed)
- `FALLBACK_GUARD=1` (auto-add Ollama fallback when fallback chain is empty)
- Optional: configure `ALT1_*` / `ALT2_*` with additional free-tier endpoints

Verify effective chain after startup:

```sh
docker compose exec openclaw node -e 'const fs=require("fs");const c=JSON.parse(fs.readFileSync("/home/node/.openclaw/openclaw.json","utf8"));console.log(JSON.stringify(c?.agents?.defaults?.model,null,2));'
```

If `fallbacks` is empty, fallback is not active and free-tier exhaustion can still hard-stop requests.

If local responses are slow or timing out, use `LOCAL_PRIMARY=0` (Gemini primary) and keep Ollama as fallback until local provider behavior is stable.

Example (`ALT1_*` with OpenAI-compatible endpoint such as OpenRouter):

```env
ALT1_PROVIDER_ID=openrouter
ALT1_PROVIDER_API=openai
ALT1_BASE_URL=https://openrouter.ai/api/v1
ALT1_API_KEY=...
ALT1_MODEL=meta-llama/llama-3.1-8b-instruct:free
```

### Hello world smoke test

Run a first local prompt to confirm OpenClaw + Ollama integration:

```sh
docker compose exec openclaw openclaw agent --local --agent main --thinking off --timeout 1200 --message "hello world" --json
```

On CPU-only local environments, this first response can take a few minutes.

For a cleaner first-step check, you can use a dedicated minimal agent:

```sh
docker compose exec openclaw sh -lc 'openclaw agents add smoke --non-interactive --workspace /home/node/.openclaw/workspace-smoke --model ollama/qwen2.5:3b-instruct-q4_K_M --json >/dev/null 2>&1 || true'
docker compose exec openclaw openclaw agent --local --agent smoke --thinking off --timeout 1200 --message "hello world" --json
```

Check active logs:

```sh
docker compose logs -f openclaw
```

### Discord setup (native OpenClaw)

1. Create a Discord app and bot in Discord Developer Portal.
2. Invite bot to your server with scopes `bot` and `applications.commands`.
3. Enable **Message Content Intent** in bot settings.
4. Put bot token into `.env` as `DISCORD_BOT_TOKEN`.
5. Start services and verify logs:

```sh
dotenvx run -- docker compose up -d
docker compose logs -f openclaw
```

### Optional: GUI mode (advanced)

If you later need on-screen rendering, configure an X11 display path for your host OS and set `DISPLAY` when running the container.

## Contributing

PRs accepted.

## License

MIT © TBD
