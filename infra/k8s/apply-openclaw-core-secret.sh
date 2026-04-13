#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-openclaw-system}"
secret_name="${SECRET_NAME:-openclaw-core-env}"
secret_dir="${1:-/etc/openclaw/openclaw-core-secret}"

if [[ ! -d "$secret_dir" ]]; then
  echo "secret directory not found: $secret_dir" >&2
  exit 1
fi

mapfile -d '' secret_files < <(find "$secret_dir" -maxdepth 1 -type f -printf '%f\0' | sort -z)

if (( ${#secret_files[@]} == 0 )); then
  echo "no secret files found in: $secret_dir" >&2
  exit 1
fi

create_args=()

for secret_key in "${secret_files[@]}"; do
  create_args+=(--from-file="${secret_key}=${secret_dir}/${secret_key}")
done

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n "$namespace" create secret generic "$secret_name" \
  "${create_args[@]}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl -n "$namespace" label secret "$secret_name" app.kubernetes.io/part-of=openclaw --overwrite >/dev/null

echo "applied secret $secret_name in namespace $namespace"
