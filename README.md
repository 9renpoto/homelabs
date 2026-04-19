# homelabs

Kubernetes-first homelab infrastructure for bringing up **NemoClaw + Ollama** on single-node k3s inside **WSL2** on Windows, with GPU-backed inference via the native NVIDIA CUDA support in WSL2 and the cluster bootstrapped by Ansible and ArgoCD from this public repository.

## Deployment path

- **Bootstrap:** Windows host → WSL2 Ubuntu (NVIDIA CUDA) → Ansible → k3s → ArgoCD
- **Workload:** `nemoclaw` with in-cluster GPU-backed Ollama
- **Out of scope for the active path:** Redis, SearXNG, Discord integration, and cloud-provider routing

The repository remains public, so runtime secrets, kubeconfig, mutable state, and backups must stay outside Git.

## Why WSL2 instead of VMware

A single NVIDIA GeForce GPU cannot be passed through to a VMware Workstation Pro VM while Windows is using that GPU for display. WSL2 solves this cleanly: Windows retains the GPU for the host display, and the WSL2 Ubuntu instance accesses CUDA through the Windows NVIDIA driver shim at `/usr/lib/wsl/lib/`.

## Repository layout

Primary bootstrap and delivery assets:

- `ansible/playbooks/wsl-openclaw-bootstrap.yml` (to be added)
- `ansible/playbooks/vmware-openclaw-bootstrap.yml` (legacy, retained for reference)
- `gitops/argocd/`
- `k8s/openclaw-core/base/`
- `infra/k8s/`

`infra/k8s/` contains operator helpers for secret application and optional PVC backup or restore.

## Windows host prerequisites

Install and prepare the following on the Windows host:

- WSL2 with Ubuntu 24.04 (enable with `wsl --install`)
- NVIDIA GPU drivers for Windows (WSL2 CUDA shim is included)
- Confirm `nvidia-smi` works inside WSL2 before bootstrapping

Enable systemd in WSL2 if not already active:

```sh
# Inside WSL2 Ubuntu
echo '[boot]' | sudo tee -a /etc/wsl.conf
echo 'systemd=true' | sudo tee -a /etc/wsl.conf
# Then restart WSL: wsl --shutdown from PowerShell
```

Verify NVIDIA CUDA is visible:

```sh
# Inside WSL2 Ubuntu
nvidia-smi
```

## Bootstrap NemoClaw on k3s

Clone the repository inside WSL2 and run the bootstrap playbook (playbook to be added):

```sh
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
brew bundle
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd ansible
ansible-playbook playbooks/wsl-openclaw-bootstrap.yml
cd ..
```

ArgoCD is pull-based. It applies manifests from `main`, so changes to `gitops/` and `k8s/` need to be committed and pushed before bootstrap can reconcile them.

The bootstrap playbook will:

- install k3s when it is missing
- install the NVIDIA container runtime packages idempotently using the WSL2 CUDA shim
- restart k3s only when package state changes
- verify that k3s renders the `nvidia` runtime and `RuntimeClass`
- install ArgoCD
- apply `openclaw-core-env` when a local secret directory exists
- bootstrap ArgoCD against this repository

## GPU-backed Ollama on k3s

Ollama runs inside the cluster with `runtimeClassName: nvidia`. The NVIDIA device plugin is managed declaratively from `k8s/nvidia-device-plugin/base` through ArgoCD.

Verify that k3s can schedule GPU workloads:

```sh
KUBECONFIG="$HOME/.kube/config" kubectl get runtimeclass nvidia
KUBECONFIG="$HOME/.kube/config" kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
KUBECONFIG="$HOME/.kube/config" kubectl -n argocd get applications nvidia-device-plugin openclaw-core
```

If GPU capacity is still missing, fix that before expecting Ollama to start.

## Local secret management

This repository uses external secret files instead of tracked `.env` files.

When runtime secrets are needed, create a local directory where **each file name is the environment variable name** and the file contents are the secret value:

```sh
sudo install -d -m 700 /etc/openclaw/openclaw-core-secret
sudo install -m 600 /dev/null /etc/openclaw/openclaw-core-secret/DISCORD_BOT_TOKEN
sudoedit /etc/openclaw/openclaw-core-secret/DISCORD_BOT_TOKEN
./infra/k8s/apply-openclaw-core-secret.sh /etc/openclaw/openclaw-core-secret
kubectl -n openclaw-system get secret openclaw-core-env
```

The bootstrap playbook looks for `/etc/openclaw/openclaw-core-secret` by default.

## Expected cluster state

After bootstrap converges:

- `openclaw-bootstrap` is `Synced` and `Healthy`
- `nvidia-device-plugin` is `Synced` and `Healthy`
- `openclaw-core` is `Synced` and `Healthy`
- namespace `openclaw-system` exists
- PVCs `ollama-data` and `openclaw-home` are bound
- deployments `ollama` and `nemoclaw` complete rollout

## Operator verification

Use these checks:

```sh
kubectl -n argocd get applications
kubectl -n openclaw-system get all
kubectl -n openclaw-system get pvc
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
kubectl -n openclaw-system rollout status deployment/ollama
kubectl -n openclaw-system logs deployment/ollama --tail=100
kubectl -n openclaw-system exec deployment/ollama -- ollama list
```

## Repository validation

```sh
shellcheck infra/k8s/*.sh
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd ansible
ansible-playbook --syntax-check playbooks/wsl-openclaw-bootstrap.yml
cd ..
```

Render the tracked Kustomize trees:

```sh
mkdir -p .tmp
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base > .tmp/openclaw-core.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/nvidia-device-plugin/base > .tmp/nvidia-device-plugin.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize gitops/argocd > .tmp/argocd-bootstrap.rendered.yaml
```

Validate manifests and policies:

```sh
docker run --rm -v "$PWD:/work" -w /work ghcr.io/yannh/kubeconform:v0.6.7 -strict -summary -ignore-missing-schemas .tmp/openclaw-core.rendered.yaml .tmp/nvidia-device-plugin.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml
docker run --rm -v "$PWD:/work" -w /work openpolicyagent/conftest:v0.58.0 test --policy policy/kubernetes .tmp/openclaw-core.rendered.yaml .tmp/nvidia-device-plugin.rendered.yaml .tmp/argocd-bootstrap.rendered.yaml gitops/argocd/applications/openclaw-bootstrap.yaml
shellcheck infra/k8s/*.sh
```

Focused manifest render:

```sh
docker run --rm -v "$PWD:/work" -w /work registry.k8s.io/kubectl:v1.31.0 kustomize k8s/openclaw-core/base
```

## Backup and restore

Reproducible rebuild is the default operating model. Use the PVC helpers only when you explicitly need to preserve `openclaw-home`:

```sh
./infra/k8s/backup-openclaw-core-pvc.sh ./openclaw-home-backup.tgz
./infra/k8s/restore-openclaw-core-pvc.sh ./openclaw-home-backup.tgz
```

Keep these outside Git and in restricted storage:

- local secret files under `/etc/openclaw/`
- `/etc/rancher/k3s/k3s.yaml`
- exported backup archives

## Contributing

PRs accepted.

## License

MIT © TBD
