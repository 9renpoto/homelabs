#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not found; NVIDIA runtime setup requires a visible host GPU" >&2
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl gpg

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --dearmor --yes -o /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  > /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y nvidia-container-toolkit nvidia-container-runtime

systemctl restart k3s

for _ in $(seq 1 60); do
  if k3s kubectl get nodes >/dev/null 2>&1; then
    break
  fi

  sleep 2
done

grep nvidia /var/lib/rancher/k3s/agent/etc/containerd/config.toml >/dev/null
k3s kubectl get runtimeclass nvidia >/dev/null

echo "nvidia runtime installation finished"
