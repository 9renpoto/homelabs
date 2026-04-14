#!/usr/bin/env bash
set -euo pipefail

plugin_version="${NVIDIA_DEVICE_PLUGIN_VERSION:-v0.19.0}"
manifest_url="https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/${plugin_version}/deployments/static/nvidia-device-plugin.yml"
wait_timeout="${WAIT_TIMEOUT_SECONDS:-300}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found" >&2
  exit 1
fi

kubectl apply -f "$manifest_url"
kubectl -n kube-system rollout status daemonset/nvidia-device-plugin-daemonset --timeout="${wait_timeout}s"

for _ in $(seq 1 60); do
  if kubectl get nodes -o jsonpath='{range .items[*]}{.status.allocatable.nvidia\.com/gpu}{"\n"}{end}' | grep -Eq '^[1-9][0-9]*$'; then
    kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
    echo "nvidia device plugin installation finished"
    exit 0
  fi

  sleep 5
done

echo "timed out waiting for allocatable nvidia.com/gpu capacity" >&2
kubectl -n kube-system get pods -l name=nvidia-device-plugin-ds >&2 || true
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu >&2 || true
exit 1
