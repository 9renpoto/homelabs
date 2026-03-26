# OpenClaw Project Roadmap

This roadmap defines a practical path from local validation on macOS to secure operation on an Ubuntu Linux server.

## Goals

- Run OpenClaw reliably and securely on an Ubuntu Linux server.
- Use macOS as the initial development and validation environment.
- Use Discord as the chat platform.
- Adopt a local, runnable model that fits constrained desktop hardware.

## Principles

- Security-first decisions for all server and automation work.
- Small, testable milestones before production deployment.
- Keep infrastructure reproducible with Docker and documented runbooks.

## Phase 1 — Local macOS Baseline (Now)

### Scope

- Confirm OpenClaw starts correctly via Docker on macOS in headless mode.
- Validate data mounting (`./data/CLAW.REZ` -> container `/data`).
- Document repeatable local startup and shutdown steps.

### Deliverables

- Verified local run procedure in `README.md`.
- Known issues list for macOS headless behavior.
- Basic health checklist for manual validation.

## Phase 2 — Local Model Selection Under Hardware Constraints

### Scope

- Select a lightweight local model suitable for constrained desktop hardware.
- Define acceptance criteria: startup time, response latency, memory footprint, and stability.
- Benchmark 2–3 candidate local models and runtimes.

### Hardware Constraints

- CPU-first inference (no discrete GPU required).
- Target memory budget: up to 16 GB system RAM.
- Stable operation under sustained local workloads.

### Candidate Direction

- Prioritize small GGUF-class models with CPU-friendly inference.
- Keep deployment local-first (no cloud dependency for core functionality).

### Deliverables

- One selected local model + runtime stack.
- Benchmark report (latency/memory/quality trade-offs).
- Local deployment instructions for reproducible setup.

## Phase 3 — Discord Chat Integration

### Scope

- Integrate Discord bot workflow for chat interactions.
- Define command surface and message handling rules.
- Add safety controls (rate limiting, input validation, and error handling).

### Deliverables

- Discord bot integration design.
- Minimal command set (`/status`, `/help`, and one gameplay-related command).
- Local integration test scenario and troubleshooting notes.

### Task Breakdown (Discord-first)

#### M3-0: Foundation (Secrets and Bot Registration)

- Create Discord application and bot user.
- Store `DISCORD_BOT_TOKEN` outside source control.
- Define minimum required bot permissions and channel scope.

**Exit criteria:** Bot identity is visible in the target server and secrets are injected via environment variables only.

#### M3-1: Message Bridge MVP (`/ask` only)

- Add a lightweight bridge service (Discord events -> OpenClaw CLI invocation).
- Implement one slash command: `/ask <message>`.
- Execute OpenClaw through existing container command path and return response to Discord.
- Add request timeout handling and user-facing fallback message.

**Exit criteria:** `/ask` returns OpenClaw output reliably in local testing for at least 5 consecutive requests.

#### M3-2: Operational Commands (`/status` and `/help`)

- Implement `/status` to report bridge health, OpenClaw reachability, and Ollama readiness.
- Implement `/help` to show supported commands and safe usage limits.
- Standardize response format for success/error cases.

**Exit criteria:** `/status` and `/help` work in the same guild/channel as `/ask` with consistent output.

#### M3-3: Safety Controls

- Add per-user and global rate limits.
- Validate and sanitize user input length/content before forwarding to OpenClaw.
- Add retry policy with bounded backoff for transient failures.
- Add structured error classes (`timeout`, `upstream_unavailable`, `validation_error`).

**Exit criteria:** abusive or malformed inputs are rejected predictably, and transient failures do not crash the bridge.

#### M3-4: Observability and Runbook

- Add structured logs for command start/end, latency, and failure reason.
- Document local smoke test and troubleshooting flow in repository docs.
- Add minimal on-call playbook: restart, health checks, and token rotation steps.

**Exit criteria:** operators can diagnose failures from logs and recover service using documented steps.

### Suggested Implementation Order

1. M3-0 Foundation
2. M3-1 `/ask` MVP
3. M3-2 `/status` and `/help`
4. M3-3 Safety controls
5. M3-4 Observability and runbook

## Phase 4 — Secure Ubuntu Server Deployment

### Scope

- Deploy on Ubuntu with hardening and operational safeguards.
- Reuse container-based setup with environment-specific configuration.
- Establish observability and incident response basics.

### Security Checklist

- Run services as non-root where possible.
- Restrict network exposure (firewall rules, least-open ports).
- Store secrets outside source control.
- Enable update/patch routine for host and containers.
- Add backup strategy for persistent data.

### Deliverables

- Ubuntu deployment guide.
- Production security baseline checklist.
- Operations runbook (start/stop/restart/logs/recovery).

## Milestone Exit Criteria

- **M1 (macOS baseline):** OpenClaw runs locally with repeatable commands.
- **M2 (model selection):** Local model selected and benchmarked within hardware constraints.
- **M3 (Discord integration):** Discord bot responds reliably in local testing.
- **M4 (Ubuntu production-ready):** Hardened deployment validated on Ubuntu.

## Risks and Mitigations

- **Hardware limits:** Use smaller quantized models and strict performance budgets.
- **Discord API changes/rate limits:** Isolate integration layer and add retry/backoff strategy.
- **Security drift on Ubuntu:** Use periodic audits and a patch cadence.

## Next Immediate Actions

1. Finalize M1 checklist and log current macOS validation results.
2. Define model benchmark template for M2.
3. Start M3-0 by preparing Discord app, bot token flow, and env var contract.
4. Implement M3-1 bridge MVP with `/ask` command only.
5. Add M3-2 `/status` and `/help` after MVP validation.
6. Prepare Ubuntu hardening template for M4.
7. Add Redis-backed middleware for prompt dedupe/state cache and validate fallback behavior.
