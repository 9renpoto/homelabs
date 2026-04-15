#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template_path="${script_dir}/ubuntu-openclaw.pkr.hcl"
vars_file="${1:-${script_dir}/variables.pkrvars.hcl}"

if [[ ! -f "${vars_file}" ]]; then
  echo "Variable file not found: ${vars_file}" >&2
  exit 1
fi

if [[ ! -f "${script_dir}/http/user-data" ]]; then
  echo "Missing ${script_dir}/http/user-data. Run infra/packer/render-user-data.sh first." >&2
  exit 1
fi

packer init "${template_path}"
packer fmt -check "${script_dir}"
packer validate -var-file="${vars_file}" "${template_path}"
packer build -var-file="${vars_file}" "${template_path}"
