#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 INPUT_TGZ" >&2
  exit 1
fi

input_path="$1"
namespace="${NAMESPACE:-openclaw-system}"
pvc_name="${PVC_NAME:-openclaw-home}"
pod_name="${POD_NAME:-openclaw-restore-$(date +%s)}"

if [[ ! -f "$input_path" ]]; then
  echo "backup archive not found: $input_path" >&2
  exit 1
fi

cleanup() {
  kubectl -n "$namespace" delete pod "$pod_name" --ignore-not-found >/dev/null 2>&1 || true
}

trap cleanup EXIT

kubectl -n "$namespace" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${pod_name}
spec:
  restartPolicy: Never
  containers:
    - name: restore
      image: alpine:3.21
      command: ["/bin/sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: ${pvc_name}
EOF

kubectl -n "$namespace" wait --for=condition=Ready --timeout=120s "pod/${pod_name}" >/dev/null
kubectl -n "$namespace" cp "$input_path" "${pod_name}:/tmp/openclaw-home-backup.tgz"
kubectl -n "$namespace" exec "$pod_name" -- sh -c 'tar -C /data -xzf /tmp/openclaw-home-backup.tgz'

echo "restored PVC $pvc_name from $input_path"
