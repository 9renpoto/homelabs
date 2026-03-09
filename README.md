# homelabs

Docker configuration for running OpenClaw (a Captain Claw reimplementation) in a headless setup on macOS, with a path toward Linux hosting.

## Roadmap

- See [ROADMAP.md](./ROADMAP.md) for the phased plan from local macOS validation to secure Ubuntu deployment.

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
- `ALT1_*` / `ALT2_*` (optional extra fallback providers)

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

Build and run all services (`openclaw`, `ollama`):

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
