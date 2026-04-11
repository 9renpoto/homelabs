#!/usr/bin/env bash
set -euo pipefail

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
namespace="${ARGOCD_NAMESPACE:-argocd}"
manifest_path="${BOOTSTRAP_MANIFEST_PATH:-$repo_root/gitops/argocd/applications/openclaw-bootstrap.yaml}"
wait_timeout="${WAIT_TIMEOUT_SECONDS:-300}"
deadline=$((SECONDS + wait_timeout))

if [[ ! -f "$manifest_path" ]]; then
  echo "bootstrap manifest not found: $manifest_path" >&2
  exit 1
fi

kubectl wait --for=condition=Established --timeout=120s crd/applications.argoproj.io >/dev/null
kubectl wait --for=condition=Established --timeout=120s crd/appprojects.argoproj.io >/dev/null
kubectl apply -n "$namespace" -f "$manifest_path"

until kubectl -n "$namespace" get application openclaw-core >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    echo "timed out waiting for ArgoCD to create application/openclaw-core" >&2
    exit 1
  fi

  sleep 5
done

kubectl -n "$namespace" get applications

echo "openclaw GitOps bootstrap finished"
