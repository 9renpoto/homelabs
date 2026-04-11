#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

install_script_url="${INSTALL_SCRIPT_URL:-https://get.k3s.io}"
k3s_channel="${K3S_CHANNEL:-stable}"
k3s_exec="${INSTALL_K3S_EXEC:-server --write-kubeconfig-mode 600}"
kubeconfig_user="${KUBECONFIG_USER:-${SUDO_USER:-}}"
tmp_script="$(mktemp)"

cleanup() {
  rm -f "$tmp_script"
}

trap cleanup EXIT

if command -v k3s >/dev/null 2>&1; then
  echo "k3s is already installed"
else
  curl -sfL "$install_script_url" -o "$tmp_script"
  INSTALL_K3S_CHANNEL="$k3s_channel" INSTALL_K3S_EXEC="$k3s_exec" sh "$tmp_script"
fi

for _ in $(seq 1 60); do
  if k3s kubectl get nodes >/dev/null 2>&1; then
    break
  fi

  sleep 2
done

k3s kubectl get nodes
k3s kubectl get pods -A

if [[ -n "$kubeconfig_user" ]]; then
  home_dir="$(getent passwd "$kubeconfig_user" | cut -d: -f6 || true)"

  if [[ -z "$home_dir" ]]; then
    echo "kubeconfig user not found: $kubeconfig_user" >&2
    exit 1
  fi

  install -d -m 700 -o "$kubeconfig_user" -g "$kubeconfig_user" "$home_dir/.kube"
  install -m 600 -o "$kubeconfig_user" -g "$kubeconfig_user" /etc/rancher/k3s/k3s.yaml "$home_dir/.kube/config"
  echo "installed kubeconfig for $kubeconfig_user at $home_dir/.kube/config"
fi

echo "k3s bootstrap finished"
