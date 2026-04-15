# homelabs

Kubernetes-first homelab infrastructure for bringing up **OpenClaw core + Ollama** on single-node k3s inside an Ubuntu VM on **VMware Workstation Pro**, with the guest image built by Packer and the cluster bootstrapped by Ansible and ArgoCD from this public repository.

## Deployment path

- **Bootstrap:** Windows host -> VMware Workstation Pro -> Packer-built Ubuntu VM -> Ansible -> k3s -> ArgoCD
- **Workload:** `openclaw-core` with in-cluster Ollama
- **Out of scope for the active path:** Redis, SearXNG, Discord integration, and cloud-provider routing

The repository remains public, so runtime secrets, kubeconfig, mutable state, and backups must stay outside Git.

## Repository layout

Primary bootstrap and delivery assets:

- `infra/packer/`
- `ansible/playbooks/vmware-openclaw-bootstrap.yml`
- `ansible/playbooks/vmware-k3s-gpu.yml`
- `gitops/argocd/`
- `k8s/openclaw-core/base/`
- `infra/k8s/`

`infra/k8s/` contains operator helpers for secret application and optional PVC backup or restore.

## Windows host prerequisites

Install and prepare the following on the Windows host:

- VMware Workstation Pro
- an Ubuntu Server ISO for the guest image build
- a reachable SSH public key for the guest bootstrap account
- a validated GPU path for the Ubuntu guest

This repository assumes the first VMware milestone still exposes `nvidia-smi` inside the Linux guest. If the guest cannot see the NVIDIA GPU, stop there before attempting the cluster bootstrap.

## Build the Ubuntu guest with Packer

Clone the repository on the machine that will run Packer and Ansible:

```sh
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
```

Render the autoinstall user-data with your SSH public key:

```sh
export PACKER_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
./infra/packer/render-user-data.sh
cp infra/packer/variables.pkrvars.hcl.example infra/packer/variables.pkrvars.hcl
```

Update `infra/packer/variables.pkrvars.hcl` with the Ubuntu ISO URL, checksum, output directory, and SSH private key path, then build the VM template:

```sh
./infra/packer/build-vmware-template.sh infra/packer/variables.pkrvars.hcl
```

The tracked Packer scaffold intentionally keeps generated `infra/packer/http/user-data` outside Git because it contains machine-local SSH material.

## Bootstrap OpenClaw on k3s

After the VMware guest is running and reachable by SSH, update `ansible/inventory/vmware.ini` with the guest IP address and operator username, then run the full bootstrap:

```sh
brew install pipx
pipx install --force ansible-core==2.18.7
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd ansible
~/.local/bin/ansible-playbook -K playbooks/vmware-openclaw-bootstrap.yml
cd ..
```

ArgoCD is pull-based. It applies manifests from `main`, so changes to `gitops/` and `k8s/` need to be committed and pushed before bootstrap can reconcile them.

The main Ansible playbook:

- installs k3s when it is missing
- installs the NVIDIA container runtime packages idempotently
- restarts k3s only when package state changes
- requires visible NVIDIA tooling before continuing and verifies that k3s rendered the `nvidia` runtime and `RuntimeClass`
- installs ArgoCD
- applies `openclaw-core-env` when a local secret directory exists
- bootstraps ArgoCD against this repository

The narrower host-only GPU step is available when you only want to refresh NVIDIA runtime state:

```sh
cd ansible
~/.local/bin/ansible-playbook -K playbooks/vmware-k3s-gpu.yml
cd ..
```

## GPU-backed Ollama on k3s

The active path now runs Ollama inside the cluster and points OpenClaw at the in-cluster `ollama` service. The NVIDIA device plugin is managed declaratively from `k8s/nvidia-device-plugin/base` through ArgoCD.

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

The Kubernetes deployment treats `openclaw-core-env` as optional, so the first bootstrap succeeds before credentials are finalized.

## Expected cluster state

After bootstrap converges:

- `openclaw-bootstrap` is `Synced` and `Healthy`
- `nvidia-device-plugin` is `Synced` and `Healthy`
- `openclaw-core` is `Synced` and `Healthy`
- namespace `openclaw-system` exists
- PVCs `ollama-data` and `openclaw-home` are bound
- deployments `ollama` and `openclaw` complete rollout

OpenClaw seeds `ollama/qwen2.5-coder:7b` as the default model and calls Ollama through `http://ollama:11434`.

## Operator verification

Use these checks:

```sh
kubectl -n argocd get applications
kubectl -n openclaw-system get all
kubectl -n openclaw-system get pvc
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
kubectl -n openclaw-system rollout status deployment/ollama
kubectl -n openclaw-system rollout status deployment/openclaw
kubectl -n openclaw-system logs deployment/ollama --tail=100
kubectl -n openclaw-system logs deployment/openclaw --tail=100
kubectl -n openclaw-system exec deployment/ollama -- ollama list
```

## First chat

If `openclaw.json` was already seeded into the PVC before the Ollama model changes, remove it once so the new seed is copied back in on the next start:

```sh
kubectl -n openclaw-system exec deployment/openclaw -- rm -f /home/node/.openclaw/openclaw.json
kubectl -n openclaw-system rollout restart deployment/openclaw
kubectl -n openclaw-system rollout status deployment/openclaw
```

Then open the UI:

```sh
kubectl -n openclaw-system port-forward svc/openclaw 3000:3000
```

Browse to `http://127.0.0.1:3000` and send the first message.

## Repository validation

Existing repository safety checks:

```sh
shellcheck infra/k8s/*.sh
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd ansible
~/.local/bin/ansible-playbook --syntax-check playbooks/vmware-k3s-gpu.yml
~/.local/bin/ansible-playbook --syntax-check playbooks/vmware-openclaw-bootstrap.yml
cd ..
```

Optional Packer scaffold checks when `packer` is installed:

```sh
export PACKER_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
./infra/packer/render-user-data.sh
packer fmt -check infra/packer
packer validate -var-file=infra/packer/variables.pkrvars.hcl infra/packer/ubuntu-openclaw.pkr.hcl
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
pipx install --force ansible-core==2.18.7
cd ansible
~/.local/bin/ansible-playbook --syntax-check playbooks/vmware-k3s-gpu.yml
~/.local/bin/ansible-playbook --syntax-check playbooks/vmware-openclaw-bootstrap.yml
cd ..
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
