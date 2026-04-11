#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
operator_user="${KUBECONFIG_USER:-${SUDO_USER:-openclaw}}"
secret_env_file="${SECRET_ENV_FILE:-/etc/openclaw/openclaw-core.env}"

KUBECONFIG_USER="$operator_user" "$script_dir/install-k3s.sh"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
"$script_dir/install-argocd.sh"

if [[ -f "$secret_env_file" ]]; then
  "$script_dir/apply-openclaw-core-secret.sh" "$secret_env_file"
else
  echo "skipping secret apply; file not found: $secret_env_file"
fi

"$script_dir/bootstrap-openclaw-gitops.sh"

echo "openclaw VM bootstrap finished for operator user $operator_user"
