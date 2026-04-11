#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-openclaw-system}"
secret_name="${SECRET_NAME:-openclaw-core-env}"
env_file="${1:-/etc/openclaw/openclaw-core.env}"

if [[ ! -f "$env_file" ]]; then
  echo "env file not found: $env_file" >&2
  exit 1
fi

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n "$namespace" create secret generic "$secret_name" \
  --from-env-file="$env_file" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl -n "$namespace" label secret "$secret_name" app.kubernetes.io/part-of=openclaw --overwrite >/dev/null

echo "applied secret $secret_name in namespace $namespace"
