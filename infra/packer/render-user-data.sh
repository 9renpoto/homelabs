#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template_path="${script_dir}/http/user-data.pkrtpl"
output_path="${script_dir}/http/user-data"

ssh_username="${PACKER_SSH_USERNAME:-ubuntu}"
vm_hostname="${PACKER_VM_HOSTNAME:-openclaw-k3s}"
ssh_public_key="${PACKER_SSH_PUBLIC_KEY:-}"
password_hash="${PACKER_PASSWORD_HASH:-\$6\$rounds=4096\$openclaw\$mT0LMs7fW.8U5Mep3Nc8BI3pJkMdmR2qxdjQbaO5SpM90oCbGyF/F7fs/3Mhqdh0dX8GZFODdgNpTi27C/med0}"

if [[ -z "${ssh_public_key}" ]]; then
  echo "PACKER_SSH_PUBLIC_KEY must be set before rendering infra/packer/http/user-data" >&2
  exit 1
fi

sed \
  -e "s|\${vm_hostname}|${vm_hostname}|g" \
  -e "s|\${ssh_username}|${ssh_username}|g" \
  -e "s|\${password_hash}|${password_hash}|g" \
  -e "s|\${ssh_public_key}|${ssh_public_key}|g" \
  "${template_path}" > "${output_path}"

echo "Rendered ${output_path}"
