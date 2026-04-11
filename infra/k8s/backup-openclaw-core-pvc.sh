#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 OUTPUT_TGZ" >&2
  exit 1
fi

output_path="$1"
namespace="${NAMESPACE:-openclaw-system}"
pvc_name="${PVC_NAME:-openclaw-home}"
pod_name="${POD_NAME:-openclaw-backup-$(date +%s)}"

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
    - name: backup
      image: alpine:3.21
      command: ["/bin/sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
          readOnly: true
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: ${pvc_name}
        readOnly: true
EOF

kubectl -n "$namespace" wait --for=condition=Ready --timeout=120s "pod/${pod_name}" >/dev/null
kubectl -n "$namespace" exec "$pod_name" -- tar -C /data -czf - . > "$output_path"

echo "wrote PVC backup to $output_path"
