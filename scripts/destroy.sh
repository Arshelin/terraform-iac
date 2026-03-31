#!/usr/bin/env bash
# destroy.sh – destroy a single component or all
# Usage: ./scripts/destroy.sh <shared|dev|prod|argo|all>
set -euo pipefail

COMPONENT="${1:?Usage: $0 <shared|dev|prod|argo|all>}"
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

function destroy_component() {
  local dir="${1}"
  local name="${2}"

  echo "==> Destroying: ${name} (${dir})"
  cd "${REPO_ROOT}/${dir}"

  terraform init -upgrade

  # Destroy Cloud SQL first to release the PSA connection before networking
  if terraform state list 2>/dev/null | grep -q "module.database"; then
    echo "    Destroying Cloud SQL first (PSA dependency)..."
    terraform destroy -target=module.database -auto-approve
  fi

  terraform destroy -auto-approve
  echo "==> ${name} destroyed."
}

case "${COMPONENT}" in
  shared|dev|prod|argo)
    read -r -p "==> Destroy '${COMPONENT}'? [y/N] " CONFIRM
    [[ "${CONFIRM}" =~ ^[Yy]$ ]] || { echo "==> Aborted."; exit 0; }
    dir=$([[ "${COMPONENT}" == "shared" ]] && echo "shared" || echo "envs/${COMPONENT}")
    destroy_component "${dir}" "${COMPONENT}"
    ;;
  all)
    echo "==> This will destroy ALL infrastructure (~\$20/day savings)"
    read -r -p "    Type 'yes' to confirm: " CONFIRM
    [[ "${CONFIRM}" == "yes" ]] || { echo "==> Aborted."; exit 0; }
    # Environments first, shared last
    for env in argo dev prod; do
      destroy_component "envs/${env}" "${env}" || true
    done
    destroy_component "shared" "shared" || true
    echo "==> All infrastructure destroyed."
    ;;
  *)
    echo "==> Unknown component: ${COMPONENT}"
    echo "    Valid options: shared, dev, prod, argo, all"
    exit 1
    ;;
esac
