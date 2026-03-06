# homelabs

Docker configuration for running OpenClaw (a Captain Claw reimplementation) in a headless setup on macOS, with a path toward Linux hosting.

## Roadmap

- See [ROADMAP.md](./ROADMAP.md) for the phased plan from local macOS validation to secure Ubuntu deployment.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- OpenClaw game data (`CLAW.REZ`) — obtain from the original Captain Claw disc or digital release

## Install

```sh
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
```

## Usage

### Place game data

Create a `data/` directory and copy `CLAW.REZ` into it:

```sh
mkdir -p data
cp /path/to/CLAW.REZ data/
```

### Start (Headless)

Build and run the container:

```sh
docker compose up --build
```

### Ollama setup for OpenClaw

The local model (`qwen2.5:0.5b`) is prepared automatically at startup by the custom Docker image entrypoints when you run:

```sh
docker compose up -d
```

If you want to test a different local model, set `OLLAMA_MODEL` when starting Compose:

```sh
OLLAMA_MODEL=qwen2.5:3b docker compose up -d
```

OpenClaw is configured automatically on startup (provider settings + default model selection).
For faster local responses in the first step, bootstrap prompt sizes are also reduced (`bootstrapMaxChars=3000`, `bootstrapTotalMaxChars=12000`).

### Hello world smoke test

Run a first local prompt to confirm OpenClaw + Ollama integration:

```sh
docker compose exec openclaw openclaw agent --local --agent main --thinking off --timeout 1200 --message "hello world" --json
```

On CPU-only local environments, this first response can take a few minutes.

For a cleaner first-step check, you can use a dedicated minimal agent:

```sh
docker compose exec openclaw sh -lc 'openclaw agents add smoke --non-interactive --workspace /home/node/.openclaw/workspace-smoke --model ollama/qwen2.5:0.5b --json >/dev/null 2>&1 || true'
docker compose exec openclaw openclaw agent --local --agent smoke --thinking off --timeout 1200 --message "hello world" --json
```

Check active logs:

```sh
docker compose logs -f openclaw
```

### Optional: GUI mode (advanced)

If you later need on-screen rendering, configure an X11 display path for your host OS and set `DISPLAY` when running the container.

## Contributing

PRs accepted.

## License

MIT © TBD
