#!/usr/bin/env bash
set -euo pipefail

namespace="${ARGOCD_NAMESPACE:-argocd}"
install_url="${ARGOCD_INSTALL_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found" >&2
  exit 1
fi

kubectl get nodes >/dev/null
kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n "$namespace" -f "$install_url"

kubectl -n "$namespace" rollout status deployment/argocd-server --timeout=300s
kubectl -n "$namespace" rollout status deployment/argocd-repo-server --timeout=300s
kubectl -n "$namespace" rollout status statefulset/argocd-application-controller --timeout=300s
kubectl -n "$namespace" get pods

echo "argocd installation finished in namespace $namespace"
