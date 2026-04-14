#!/usr/bin/env bash
set -euo pipefail

namespace="${ARGOCD_NAMESPACE:-argocd}"
install_url="${ARGOCD_INSTALL_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"
wait_timeout="${WAIT_TIMEOUT_SECONDS:-300}"
deadline=$((SECONDS + wait_timeout))

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found" >&2
  exit 1
fi

kubectl get nodes >/dev/null
kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
if ! kubectl -n "$namespace" get deployment argocd-server >/dev/null 2>&1; then
  kubectl apply --server-side -n "$namespace" -f "$install_url"
fi

if ! kubectl -n "$namespace" get deployment argocd-repo-server >/dev/null 2>&1; then
  kubectl apply --server-side -n "$namespace" -f "$install_url"
fi

until kubectl -n "$namespace" get deployment argocd-repo-server >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    echo "timed out waiting for deployment/argocd-repo-server in namespace $namespace" >&2
    kubectl -n "$namespace" get deployments >&2 || true
    exit 1
  fi
  sleep 5
done

kubectl -n "$namespace" patch deployment argocd-repo-server --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/initContainers/0/args/0","value":"/bin/cp --update=none /usr/local/bin/argocd /var/run/argocd/argocd && /bin/ln -sfn /var/run/argocd/argocd /var/run/argocd/argocd-cmp-server"}]'

kubectl -n "$namespace" rollout status deployment/argocd-server --timeout=300s
kubectl -n "$namespace" rollout status deployment/argocd-repo-server --timeout=300s
kubectl -n "$namespace" rollout status statefulset/argocd-application-controller --timeout=300s
kubectl -n "$namespace" get pods

echo "argocd installation finished in namespace $namespace"
