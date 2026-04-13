#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
operator_user="${KUBECONFIG_USER:-${SUDO_USER:-$USER}}"
secret_source_dir="${SECRET_SOURCE_DIR:-/etc/openclaw/openclaw-core-secret}"

KUBECONFIG_USER="$operator_user" "$script_dir/install-k3s.sh"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
"$script_dir/install-argocd.sh"

if [[ -d "$secret_source_dir" ]]; then
  "$script_dir/apply-openclaw-core-secret.sh" "$secret_source_dir"
else
  echo "skipping secret apply; directory not found: $secret_source_dir"
fi

"$script_dir/bootstrap-openclaw-gitops.sh"

echo "openclaw WSL bootstrap finished for operator user $operator_user"
