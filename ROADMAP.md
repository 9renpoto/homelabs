# OpenClaw Homelabs Roadmap

This roadmap tracks the current direction of this repository: a greenfield, Kubernetes-native OpenClaw deployment for a single home-PC environment, with reproducible rebuilds as the primary operational goal and production-adjacent technology validation as a parallel objective.

## Goals

- Bring up OpenClaw core reliably on single-node k3s inside the existing WSL2 Ubuntu instance.
- Manage deployment from this public repository through ArgoCD.
- Keep runtime secrets, backup artifacts, and mutable state outside Git.
- Retire Docker Compose as an operating path for this repository.
- Keep optional supporting assets reviewable in-repo only when they do not redefine the primary Kubernetes-first direction.

## Principles

- Prefer reproducible scrap-and-rebuild over backup automation in the first milestone.
- Keep the first deployed footprint small: OpenClaw core first, optional services later.
- Use pull-based GitOps for cluster reconciliation.
- Design for one home-PC installation; separate staging is out of scope for the baseline.
- Treat the homelab as a technology-validation environment: prefer production-adjacent building blocks over home-lab-only shortcuts.
- Structure infrastructure work so it can be rendered, validated, and regression-checked in-repo, similar to an IaC/CDK workflow.
- Manage local secrets outside Git without relying on tracked `.env` files.

## IaC Technology Selection Direction

### Layer split

- **WSL2 layer:** run k3s directly inside the existing WSL2 Ubuntu instance on Windows.
- **Guest configuration layer:** manage repeatable in-guest operating-system configuration after first boot.
- **Cluster application layer:** manage Kubernetes resources delivered into k3s through GitOps.

### Current recommendation

- **WSL2 layer:** use the existing WSL2 Ubuntu instance. Scripts in `infra/k8s/` are Linux-generic and run in WSL2 without modification.
- **Guest configuration layer:** keep current shell-based setup for now, but evaluate **Ansible** as the default path when in-guest configuration grows beyond simple bootstrap scripts.
- **Cluster application layer:** use **Kustomize + ArgoCD** as the default GitOps path.

## Phase 1 — WSL2 and Cluster Bootstrap (Current)

### Scope

- Use the existing WSL2 Ubuntu instance as the k3s host.
- Install k3s and ArgoCD inside WSL2.
- Bootstrap ArgoCD against this repository.
- Roll out the initial `openclaw-core` workload into `openclaw-system`.
- Keep bootstrap assets reviewable and testable from the repository before they are applied.

### Deliverables

- Repeatable bootstrap flow using `infra/k8s/bootstrap-openclaw-wsl.sh`.
- Working bootstrap scripts in `infra/k8s/`.
- ArgoCD bootstrap from `gitops/argocd/`.
- Initial `k8s/openclaw-core/base/` deployment healthy on k3s.
- A repo-local validation path for infrastructure changes such as render checks, policy checks, and script verification.

### Exit Criteria

- `openclaw-bootstrap` is `Synced` and `Healthy`.
- `openclaw-core` is `Synced` and `Healthy`.
- Namespace `openclaw-system` exists.
- PVC `openclaw-home` is bound.
- Deployment `openclaw` completes rollout.
- Bootstrap-related manifests and policies can be validated from the repository before live rollout.

## Phase 2 — Infrastructure Testability and Change Safety

### Scope

- Expand the feedback loop for infrastructure changes so work can progress with fast repo-local checks.
- Favor declarative assets and validation steps that resemble CDK-style iteration.
- Keep bootstrap scripts, GitOps manifests, and safety policies aligned so changes are testable before they reach WSL2.
- Advance IaC technology selection separately for host setup and in-guest configuration management.

### Deliverables

- Reliable render checks for GitOps-managed Kubernetes resources.
- Policy and schema validation that gate manifest changes.
- A documented habit of adding or updating repo-local validation when infrastructure behavior changes materially.
- A documented default choice for each IaC layer.

### Exit Criteria

- Material infrastructure changes have a corresponding repo-local validation path.
- GitOps manifests remain reviewable without immediate access to the target machine.
- The repo supports iterative infrastructure work with feedback closer to application development workflows.

## Phase 3 — Runtime Secret Handling and Operator Flow

### Scope

- Finalize local secret injection for `openclaw-core-env`.
- Remove tracked `.env` files from the workflow.
- Keep bootstrap functional even when the secret directory is not present yet.
- Document first-line operator checks and recovery steps.

### Deliverables

- Stable use of `/etc/openclaw/openclaw-core-secret/` with `infra/k8s/apply-openclaw-core-secret.sh`.
- Documented verification flow for rollout, logs, PVC state, and ArgoCD applications.
- Clear separation between Git-managed manifests and local secret material.

### Exit Criteria

- Operators can inject or rotate runtime env without editing Git-managed manifests.
- Bootstrap succeeds before final secrets are available.
- Health and rollout checks are documented and repeatable.

## Phase 4 — Optional Component Evaluation

### Scope

- Decide when, if ever, to bring lower-priority supporting components into the k3s path.
- Preserve `ollama/` and `searxng/` only as future options, not as the default operating path.
- Treat Redis, SearXNG, Ollama, and Discord integration as follow-on work, not first-milestone blockers.

### Deliverables

- Decision record for each optional component: stay dormant, move to k3s, or defer.
- Kubernetes manifests and policies for any promoted component.
- Updated operator runbooks for any expanded footprint.

### Exit Criteria

- Each promoted component has a clear operational owner, secret strategy, and validation path.
- OpenClaw core remains healthy while surrounding components are added incrementally.

## Phase 5 — Backup, Restore, and Operational Hardening

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

- **Public repository exposure:** keep all real secrets and backup artifacts outside Git.
- **Bootstrap drift:** validate Kustomize output, schema conformance, and policy checks in CI and before major manifest changes.
- **Over-expanding too early:** keep the first milestone limited to OpenClaw core on k3s.
- **Home-lab recovery complexity:** favor rebuildable infrastructure and local secret injection over fragile in-repo state.
- **Single-host bias:** avoid choosing tools solely because the installation is small; keep the architecture close enough to production patterns that the repo remains useful for technology validation.

## Next Immediate Actions

1. Keep the WSL2 -> k3s -> ArgoCD -> OpenClaw bootstrap path repeatable.
2. Finalize the local secret-directory workflow for `openclaw-core-env`.
3. Strengthen repo-local validation so infrastructure changes can be tested before rollout.
4. Keep **Kustomize + ArgoCD** as the default for cluster application delivery.
5. Decide when, if ever, to promote `ollama/` and `searxng/` into the Kubernetes path.
6. Maintain CI checks for rendered manifests and Kubernetes safety policies.
