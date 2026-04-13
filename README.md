# homelabs

Kubernetes-first homelab infrastructure for bringing up **OpenClaw core** on single-node k3s inside the existing WSL2 Ubuntu instance, bootstrapped by ArgoCD from this public repository.

## Current direction

- **Primary path:** WSL2 Ubuntu -> k3s -> ArgoCD -> `openclaw-core`
- **Current milestone:** get a simple OpenClaw deployment healthy on k3s with reproducible bootstrap and repo-local validation
- **Not part of the first rollout:** Redis, SearXNG, Ollama-on-k3s, Discord integration, or cloud-provider routing
- **Retired path:** Docker Compose is no longer the operating model for this repository

The repository remains public, so runtime secrets, kubeconfig, mutable state, and backups must stay outside Git.

## Repository layout

Primary bootstrap and delivery assets:

- `infra/k8s/bootstrap-openclaw-wsl.sh`
- `infra/k8s/install-k3s.sh`
- `infra/k8s/install-argocd.sh`
- `infra/k8s/apply-openclaw-core-secret.sh`
- `infra/k8s/bootstrap-openclaw-gitops.sh`
- `gitops/argocd/`
- `k8s/openclaw-core/base/`

Lower-priority assets retained for future evaluation:

- `ollama/`
- `searxng/`

Those retained directories are not part of the active bootstrap path.

## Windows host prerequisites

The bootstrap scripts run inside WSL2 Ubuntu.

From an elevated PowerShell session:

```powershell
wsl --install
```

If WSL is already installed but Ubuntu is not:

```powershell
wsl --install -d Ubuntu
```

Inside Ubuntu, enable systemd:

```sh
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF
```

Then restart WSL from PowerShell:

```powershell
wsl --shutdown
wsl
```

Verify:

```sh
systemctl is-system-running
```

## Bootstrap OpenClaw on k3s

Clone the repository inside WSL2:

```sh
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
```

Run the bootstrap:

```sh
sudo KUBECONFIG_USER="${USER}" ./infra/k8s/bootstrap-openclaw-wsl.sh
kubectl get nodes
kubectl get pods -A
```

This wrapper:

- installs k3s
- installs ArgoCD
- applies `openclaw-core-env` when a local secret directory exists
- bootstraps ArgoCD against this repository

## Local secret management

This repository no longer uses tracked `.env` files.

When runtime secrets are needed, create a local directory where **each file name is the environment variable name** and the file contents are the secret value:

```sh
sudo install -d -m 700 /etc/openclaw/openclaw-core-secret
sudo install -m 600 /dev/null /etc/openclaw/openclaw-core-secret/DISCORD_BOT_TOKEN
sudoedit /etc/openclaw/openclaw-core-secret/DISCORD_BOT_TOKEN
./infra/k8s/apply-openclaw-core-secret.sh /etc/openclaw/openclaw-core-secret
kubectl -n openclaw-system get secret openclaw-core-env
```

The bootstrap wrapper looks for `/etc/openclaw/openclaw-core-secret` by default.

The Kubernetes deployment still treats `openclaw-core-env` as optional, so the first bootstrap can succeed before any real secret material is present.

## GitOps bootstrap flow

After ArgoCD is installed, the one-time bootstrap application points ArgoCD at:

- `gitops/argocd/projects/openclaw-core.yaml`
- `gitops/argocd/applications/openclaw-core.yaml`
- `k8s/openclaw-core/base/`

The expected result is:

- `openclaw-bootstrap` becomes `Synced` and `Healthy`
- `openclaw-core` becomes `Synced` and `Healthy`
- namespace `openclaw-system` exists
- PVC `openclaw-home` is bound
- deployment `openclaw` completes rollout

## Operator verification

Use these checks in order:

```sh
kubectl -n argocd get applications
kubectl -n openclaw-system get all
kubectl -n openclaw-system get pvc
kubectl -n openclaw-system rollout status deployment/openclaw
kubectl -n openclaw-system logs deployment/openclaw --tail=100
```

Basic maintenance checks:

```sh
kubectl get nodes
kubectl -n argocd get applications
kubectl -n openclaw-system get pods,svc,ingress,pvc
kubectl -n openclaw-system describe deployment openclaw
```

## Repository validation

Render the tracked Kustomize trees:

```sh
mkdir -p .tmp
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base > .tmp/openclaw-core.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize gitops/argocd > .tmp/argocd-bootstrap.rendered.yaml
```

Validate manifests and policies:

```sh
docker run --rm -v "$PWD:/work" -w /work ghcr.io/yannh/kubeconform:v0.6.7 -strict -summary -ignore-missing-schemas .tmp/openclaw-core.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work openpolicyagent/conftest:v0.58.0 test --policy policy/kubernetes .tmp/openclaw-core.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml gitops/argocd/applications/openclaw-bootstrap.yaml
shellcheck infra/k8s/*.sh
```

Focused manifest render:

```sh
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base
```

## Backup and restore

Reproducible rebuild is the current priority, but PVC backup helpers are available:

```sh
./infra/k8s/backup-openclaw-core-pvc.sh ./openclaw-home-backup.tgz
./infra/k8s/restore-openclaw-core-pvc.sh ./openclaw-home-backup.tgz
```

Keep these outside Git and in restricted storage:

- local secret files under `/etc/openclaw/`
- `/etc/rancher/k3s/k3s.yaml`
- exported backup archives

## Optional retained assets

`ollama/` and `searxng/` remain in the repository because they may be reused later, but they are currently **out of scope for the active bootstrap path** and should not drive documentation or operator guidance.

## Contributing

PRs accepted.

## License

MIT © TBD
