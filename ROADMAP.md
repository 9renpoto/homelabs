# OpenClaw Homelabs Roadmap

This roadmap describes the active direction of this repository: a Kubernetes-native OpenClaw deployment for a single home-PC environment, with reproducible rebuilds as the primary operational goal and production-adjacent technology validation as a parallel objective.

## Goals

- Bring up OpenClaw core reliably on single-node k3s inside the existing WSL2 Ubuntu instance.
- Manage deployment from this public repository through ArgoCD.
- Keep runtime secrets, backup artifacts, and mutable state outside Git.
- Keep optional supporting assets reviewable in-repo only when they do not redefine the primary Kubernetes-first direction.

## Principles

- Prefer reproducible scrap-and-rebuild over backup automation in the first milestone.
- Keep the first deployed footprint small: OpenClaw core first, optional services later.
- Use pull-based GitOps for cluster reconciliation.
- Design for one home-PC installation; separate staging is out of scope for the baseline.
- Treat the homelab as a technology-validation environment: prefer production-adjacent building blocks over home-lab-only shortcuts.
- Structure infrastructure work so it can be rendered, validated, and regression-checked in-repo, similar to an IaC/CDK workflow.
- Manage local secrets outside Git without relying on tracked `.env` files.

## Active stack

- Use the existing WSL2 Ubuntu instance as the k3s host.
- Use **Ansible** as the default automation path for WSL/k3s bootstrap.
- Use **Kustomize + ArgoCD** as the default GitOps path.

## Current delivery scope

- Use the existing WSL2 Ubuntu instance as the k3s host.
- Install k3s and ArgoCD inside WSL2.
- Bootstrap ArgoCD against this repository.
- Run `openclaw-core` and Ollama in `openclaw-system`.
- Keep bootstrap assets reviewable and testable from the repository before they are applied.

## Current repository deliverables

- Repeatable bootstrap flow using `ansible/playbooks/wsl-openclaw-bootstrap.yml`.
- Working Ansible playbooks and roles for WSL/k3s bootstrap.
- ArgoCD bootstrap from `gitops/argocd/`.
- `k8s/openclaw-core/base/` and `k8s/nvidia-device-plugin/base/` deployment healthy on k3s.
- A repo-local validation path for infrastructure changes such as render checks, policy checks, and script verification.

## Current success criteria

- `openclaw-bootstrap` is `Synced` and `Healthy`.
- `nvidia-device-plugin` is `Synced` and `Healthy`.
- `openclaw-core` is `Synced` and `Healthy`.
- Namespace `openclaw-system` exists.
- PVC `ollama-data` is bound.
- PVC `openclaw-home` is bound.
- Deployment `ollama` completes rollout.
- Deployment `openclaw` completes rollout.
- Bootstrap-related manifests and policies can be validated from the repository before live rollout.

## Ongoing engineering focus

- Expand the feedback loop for infrastructure changes so work can progress with fast repo-local checks.
- Favor declarative assets and validation steps that resemble CDK-style iteration.
- Keep bootstrap scripts, GitOps manifests, and safety policies aligned so changes are testable before they reach WSL2.
- Advance IaC technology selection separately for WSL/k3s bootstrap and cluster application delivery.

- Reliable render checks for GitOps-managed Kubernetes resources.
- Policy and schema validation that gate manifest changes.
- A documented habit of adding or updating repo-local validation when infrastructure behavior changes materially.
- A documented default choice for each IaC layer.

- Material infrastructure changes have a corresponding repo-local validation path.
- GitOps manifests remain reviewable without immediate access to the target machine.
- The repo supports iterative infrastructure work with feedback closer to application development workflows.

## Operator flow

- Finalize local secret injection for `openclaw-core-env`.
- Remove tracked `.env` files from the workflow.
- Keep bootstrap functional even when the secret directory is not present yet.
- Document first-line operator checks and recovery steps.

- Stable use of `/etc/openclaw/openclaw-core-secret/` with `infra/k8s/apply-openclaw-core-secret.sh`.
- Documented verification flow for rollout, logs, PVC state, and ArgoCD applications.
- Clear separation between Git-managed manifests and local secret material.

- Operators can inject or rotate runtime env without editing Git-managed manifests.
- Bootstrap succeeds before final secrets are available.
- Health and rollout checks are documented and repeatable.

## Optional component stance

- Decide when, if ever, to bring lower-priority supporting components into the k3s path.
- Treat Redis, SearXNG, and Discord integration as follow-on work, not first-milestone blockers.

- Decision record for each optional component: stay dormant, move to k3s, or defer.
- Kubernetes manifests and policies for any promoted component.
- Updated operator runbooks for any expanded footprint.

- Each promoted component has a clear operational owner, secret strategy, and validation path.
- OpenClaw core remains healthy while surrounding components are added incrementally.

## Backup and restore stance

- Add controlled backup and restore procedures after the rebuild path is stable.
- Protect VM-local secrets, kubeconfig, and PVC data in restricted storage.
- Tighten operational checks without sacrificing rebuild simplicity.

- Validated usage of `infra/k8s/backup-openclaw-core-pvc.sh`.
- Validated usage of `infra/k8s/restore-openclaw-core-pvc.sh`.
- Defined storage locations and handling rules for secret files, kubeconfig, and archives.

- Operators can back up and intentionally restore `openclaw-home` without changing manifests.
- Backup artifacts remain outside Git and in restricted storage.
- Restore remains an explicit operator action against a prepared PVC.

## Risks and Mitigations

- **Public repository exposure:** keep all real secrets and backup artifacts outside Git.
- **Bootstrap drift:** validate Kustomize output, schema conformance, and policy checks in CI and before major manifest changes.
- **Over-expanding too early:** keep the first milestone limited to OpenClaw core on k3s.
- **Home-lab recovery complexity:** favor rebuildable infrastructure and local secret injection over fragile in-repo state.
- **Single-host bias:** avoid choosing tools solely because the installation is small; keep the architecture close enough to production patterns that the repo remains useful for technology validation.

## Current priorities

1. Keep the WSL2 -> k3s -> ArgoCD -> OpenClaw bootstrap path repeatable.
2. Keep the local secret-directory workflow for `openclaw-core-env` stable.
3. Strengthen repo-local validation so infrastructure changes can be tested before rollout.
4. Keep **Kustomize + ArgoCD** as the default for cluster application delivery.
5. Revisit optional services only when they add value to the active k3s path.
6. Maintain CI checks for rendered manifests and Kubernetes safety policies.
