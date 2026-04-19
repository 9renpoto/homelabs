#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template_path="${script_dir}/http/user-data.pkrtpl"
output_path="${script_dir}/http/user-data"

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

ssh_username="${PACKER_SSH_USERNAME:-ubuntu}"
vm_hostname="${PACKER_VM_HOSTNAME:-openclaw-k3s}"
ssh_public_key="$(printf '%s' "${PACKER_SSH_PUBLIC_KEY:-}" | tr -d '\r\n')"
password_hash="${PACKER_PASSWORD_HASH:-\$6\$rounds=4096\$openclaw\$mT0LMs7fW.8U5Mep3Nc8BI3pJkMdmR2qxdjQbaO5SpM90oCbGyF/F7fs/3Mhqdh0dX8GZFODdgNpTi27C/med0}"

if [[ -z "${ssh_public_key}" ]]; then
  echo "PACKER_SSH_PUBLIC_KEY must be set before rendering infra/packer/http/user-data" >&2
  exit 1
fi

escaped_vm_hostname="$(escape_sed_replacement "${vm_hostname}")"
escaped_ssh_username="$(escape_sed_replacement "${ssh_username}")"
escaped_password_hash="$(escape_sed_replacement "${password_hash}")"
escaped_ssh_public_key="$(escape_sed_replacement "${ssh_public_key}")"

sed \
  -e "s|\${vm_hostname}|${escaped_vm_hostname}|g" \
  -e "s|\${ssh_username}|${escaped_ssh_username}|g" \
  -e "s|\${password_hash}|${escaped_password_hash}|g" \
  -e "s|\${ssh_public_key}|${escaped_ssh_public_key}|g" \
  "${template_path}" > "${output_path}"

echo "Rendered ${output_path}"
