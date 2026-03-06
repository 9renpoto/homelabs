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
3. Draft Discord bot command/spec skeleton for M3.
4. Prepare Ubuntu hardening template for M4.
