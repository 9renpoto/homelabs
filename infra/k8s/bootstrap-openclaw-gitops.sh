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

wait_for_application() {
  local app_name="$1"

  until kubectl -n "$namespace" get application "$app_name" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      echo "timed out waiting for ArgoCD to create application/$app_name" >&2
      exit 1
    fi

    sleep 5
  done
}

wait_for_application_health() {
  local app_name="$1"
  local sync_status
  local health_status

  while true; do
    sync_status="$(kubectl -n "$namespace" get application "$app_name" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n "$namespace" get application "$app_name" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

    if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
      return 0
    fi

    if (( SECONDS >= deadline )); then
      echo "timed out waiting for application/$app_name to become Synced and Healthy (sync=${sync_status:-unknown} health=${health_status:-unknown})" >&2
      kubectl -n "$namespace" get application "$app_name" -o yaml >&2 || true
      exit 1
    fi

    sleep 5
  done
}

wait_for_application openclaw-bootstrap
wait_for_application openclaw-core
wait_for_application_health openclaw-bootstrap
wait_for_application_health openclaw-core

if (( SECONDS >= deadline )); then
  echo "timed out waiting for ArgoCD bootstrap to complete" >&2
  exit 1
fi

kubectl -n "$namespace" get applications

echo "openclaw GitOps bootstrap finished"
