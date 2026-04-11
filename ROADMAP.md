# OpenClaw Homelabs Roadmap

This roadmap tracks the current direction of this repository: a greenfield, Kubernetes-native OpenClaw deployment for a single home-PC environment, with reproducible rebuilds as the primary operational goal and production-adjacent technology validation as a parallel objective.

## Goals

- Bring up OpenClaw core reliably on a dedicated Ubuntu VM running single-node k3s.
- Manage deployment from this public repository through ArgoCD.
- Keep runtime secrets, backup artifacts, and mutable state outside Git.
- Preserve a Docker Compose path for local validation while the k3s path becomes the primary deployment target.
- Use technology choices that stay close to production-grade operating models even when the physical footprint is only one Windows host plus one VM.

## Principles

- Prefer reproducible scrap-and-rebuild over backup automation in the first milestone.
- Keep the first deployed footprint small: OpenClaw core first, optional services later.
- Use pull-based GitOps for cluster reconciliation.
- Design for one home-PC installation; separate staging is out of scope for the baseline.
- Treat the homelab as a technology-validation environment: prefer production-adjacent building blocks over home-lab-only shortcuts.
- Structure infrastructure work so it can be rendered, validated, and regression-checked in-repo, similar to an IaC/CDK workflow.

## IaC Technology Selection Direction

### Layer split

- **Hyper-V host layer:** create and manage the VM itself on the Windows host.
- **Guest bootstrap layer:** establish the Ubuntu VM's initial machine state.
- **Guest configuration layer:** manage repeatable in-guest operating-system configuration after first boot.
- **Cluster application layer:** manage Kubernetes resources delivered into k3s through GitOps.

### Current recommendation

- **Hyper-V host layer:** use **PowerShell + Hyper-V module** as the primary IaC surface.
- **Guest bootstrap layer:** use **cloud-init** for first-boot user, SSH, package, and baseline OS setup.
- **Guest configuration layer:** keep current shell-based setup for now, but evaluate **Ansible** as the default path when in-guest configuration grows beyond simple bootstrap scripts.
- **Cluster application layer:** use **Kustomize + ArgoCD** as the default GitOps path.

### Evaluation rules

- Prefer tools with strong native support for their target layer over generic tools that only work through wrappers.
- Keep Kubernetes delivery Git-native unless there is a clear need for an external state-managed tool.
- Revisit higher-level generators only when manifest duplication or abstraction pressure becomes hard to manage with the current Kustomize structure.

## Phase 1 — VM and Cluster Bootstrap (Current)

### Scope

- Create a dedicated Ubuntu VM on Hyper-V.
- Seed the guest with the provided cloud-init template.
- Install k3s and ArgoCD inside the VM.
- Bootstrap ArgoCD against this repository.
- Roll out the initial `openclaw-core` workload into `openclaw-system`.
- Keep the bootstrap assets reviewable and testable from the repository before they are applied to the VM.

### Deliverables

- Repeatable VM creation flow from `infra/hyperv/New-OpenClawK3sVm.ps1`.
- Repeatable guest bootstrap using `infra/cloud-init/openclaw-k3s-user-data.yaml`.
- Working bootstrap scripts in `infra/k8s/`.
- ArgoCD bootstrap from `gitops/argocd/`.
- Initial `k8s/openclaw-core/base/` deployment healthy on k3s.
- A repo-local validation path for infrastructure changes such as render checks, policy checks, and script verification where practical.

### Exit Criteria

- `openclaw-bootstrap` is `Synced` and `Healthy`.
- `openclaw-core` is `Synced` and `Healthy`.
- Namespace `openclaw-system` exists.
- PVC `openclaw-home` is bound.
- Deployment `openclaw` completes rollout.
- The bootstrap-related manifests and policies can be validated from the repository before live rollout.

## Phase 2 — Infrastructure Testability and Change Safety

### Scope

- Expand the feedback loop for infrastructure changes so work can progress with fast repo-local checks.
- Favor declarative assets and validation steps that resemble CDK-style iteration, even though the current stack is shell scripts plus Kubernetes manifests.
- Keep bootstrap scripts, GitOps manifests, and safety policies aligned so changes are testable before they reach the VM.
- Advance IaC technology selection separately for Hyper-V VM construction and for in-guest configuration management.

### Deliverables

- Reliable render checks for GitOps-managed Kubernetes resources.
- Policy and schema validation that gate manifest changes.
- A documented habit of adding or updating repo-local validation when infrastructure behavior changes materially.
- A documented default choice for each IaC layer: Hyper-V host, guest bootstrap, guest configuration, and cluster application delivery.

### Exit Criteria

- Material infrastructure changes have a corresponding repo-local validation path.
- GitOps manifests remain reviewable without needing immediate access to the target VM.
- The repo supports iterative infrastructure work with feedback closer to application development workflows.
- Default IaC choices are clear enough that follow-up work does not reopen the same tooling decision each time.

## Phase 3 — Runtime Secret Handling and Operator Flow

### Scope

- Finalize VM-local secret injection for `openclaw-core-env`.
- Keep the bootstrap path functional even when the secret is not present yet.
- Document first-line operator checks and recovery steps.

### Deliverables

- Stable use of `/etc/openclaw/openclaw-core.env` with `infra/k8s/apply-openclaw-core-secret.sh`.
- Documented verification flow for rollout, logs, PVC state, and ArgoCD applications.
- Clear separation between Git-managed manifests and VM-local secret material.

### Exit Criteria

- Operators can inject or rotate runtime env without editing Git-managed manifests.
- Bootstrap succeeds before final secrets are available.
- Health and rollout checks are documented and repeatable.

## Phase 4 — Local Validation Path Maintenance

### Scope

- Keep the Docker Compose path usable for local validation and config iteration.
- Preserve deterministic OpenClaw defaults through source-controlled managed config and workspace templates.
- Continue validating provider routing and smoke flows locally.

### Deliverables

- Working Compose stack with `openclaw`, `ollama`, `redis`, and `searxng`.
- Managed OpenClaw defaults in `openclaw/openclaw.managed.json`.
- Synced workspace templates from `openclaw/workspace/AGENTS.md` and `openclaw/workspace-smoke/AGENTS.md`.
- Repeatable smoke command for local agent execution.

### Exit Criteria

- `dotenvx run -- docker compose up -d --build` remains a valid local validation path.
- Rebuilding `openclaw` applies managed config and workspace template changes predictably.
- Local provider routing and fallback behavior can be inspected and reproduced.

## Phase 5 — Optional Service Migration and Expansion

### Scope

- Evaluate when to bring Compose-only services into the k3s path.
- Migrate only after OpenClaw core is stable on Kubernetes.
- Treat Ollama, Redis, SearXNG, and Discord integration as follow-on work, not first-milestone blockers.

### Deliverables

- Decision record for each optional service: stay local-only, move to k3s, or defer.
- Kubernetes manifests and policies for any promoted service.
- Updated operator runbooks for the expanded footprint.

### Exit Criteria

- Each migrated service has a clear operational owner, secret strategy, and validation path.
- OpenClaw core remains healthy while surrounding services are added incrementally.

## Phase 6 — Backup, Restore, and Operational Hardening

### Scope

- Add controlled backup and restore procedures after the rebuild path is stable.
- Protect VM-local secrets, kubeconfig, and PVC data in restricted storage.
- Tighten operational checks without sacrificing rebuild simplicity.

### Deliverables

- Validated usage of `infra/k8s/backup-openclaw-core-pvc.sh`.
- Validated usage of `infra/k8s/restore-openclaw-core-pvc.sh`.
- Defined storage locations and handling rules for secret files, kubeconfig, and archives.

### Exit Criteria

- Operators can back up and intentionally restore `openclaw-home` without changing manifests.
- Backup artifacts remain outside Git and in restricted storage.
- Restore remains an explicit operator action against a prepared PVC.

## Risks and Mitigations

- **Public repository exposure:** keep all real secrets, decrypted env files, and backup artifacts outside Git.
- **Bootstrap drift:** validate Kustomize output, schema conformance, and policy checks in CI and before major manifest changes.
- **Over-expanding too early:** keep the first milestone limited to OpenClaw core on k3s.
- **Home-lab recovery complexity:** favor rebuildable infrastructure and VM-local secret injection over fragile in-repo state.
- **Single-host bias:** avoid choosing tools solely because the installation is small; keep the architecture close enough to production patterns that the repo remains useful for technology validation.

## Next Immediate Actions

1. Complete the Hyper-V VM construction path first, including script-level tests for `infra/hyperv/New-OpenClawK3sVm.ps1`.
2. Keep the Hyper-V → Ubuntu → k3s → ArgoCD → OpenClaw bootstrap path repeatable.
3. Strengthen repo-local validation so infrastructure changes can be tested before VM rollout.
4. Keep **PowerShell + Hyper-V module** as the default for VM construction on the Windows host.
5. Keep **cloud-init** as the default for first-boot guest bootstrap, and evaluate **Ansible** when in-guest configuration grows beyond bootstrap scripts.
6. Keep **Kustomize + ArgoCD** as the default for cluster application delivery.
7. Verify the VM-local secret workflow for `openclaw-core-env`.
8. Maintain CI checks for rendered manifests and Kubernetes safety policies.
9. Keep the Compose path usable for local config iteration and smoke tests.
10. Decide when, if ever, to migrate Redis, SearXNG, Ollama, and Discord-related pieces into k3s.
