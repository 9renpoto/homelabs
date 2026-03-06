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
- `OLLAMA_MODEL` (worker role)

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

### Gemini (planner) + Ollama (worker)

This repository supports a dual-role model setup:

- Planner/instruction role: `google/gemini-*` (when `GEMINI_API_KEY` is set)
- Worker/execution role: `ollama/*`

At startup, `openclaw` applies this behavior automatically:

- if `GEMINI_API_KEY` exists, default primary model becomes `google/${GEMINI_MODEL}`
- if `GEMINI_API_KEY` exists, default fallback model becomes `ollama/${OLLAMA_MODEL}`
- if `GEMINI_API_KEY` is empty, default primary model falls back to `ollama/${OLLAMA_MODEL}`

This allows running Gemini in free tier for direction while keeping local task execution on Ollama.

Note: in this setup, Gemini is connected through OpenClaw's native `google-generative-ai` provider.

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
