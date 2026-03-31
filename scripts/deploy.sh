#!/usr/bin/env bash
# deploy.sh – plan & apply a single component
# Usage: ./scripts/deploy.sh <shared|dev|prod|argo>
set -euo pipefail

COMPONENT="${1:?Usage: $0 <shared|dev|prod|argo>}"

case "${COMPONENT}" in
  shared) DIR="shared" ;;
  dev|prod|argo) DIR="envs/${COMPONENT}" ;;
  *)
    echo "==> Unknown component: ${COMPONENT}"
    echo "    Valid options: shared, dev, prod, argo"
    exit 1
    ;;
esac

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
TARGET="${REPO_ROOT}/${DIR}"

# Fetch GitHub PAT from Secret Manager for shared layer (Cloud Build needs it)
if [[ "${COMPONENT}" == "shared" && -z "${TF_VAR_github_pat_token:-}" ]]; then
  PROJECT_ID=$(grep -oP 'project_id\s*=\s*"\K[^"]+' "${REPO_ROOT}/shared/terraform.tfvars")
  echo "==> Fetching GitHub PAT from Secret Manager..."
  TF_VAR_github_pat_token=$(gcloud secrets versions access latest \
    --secret=github-pat-terraform --project="${PROJECT_ID}")
  export TF_VAR_github_pat_token
fi

# Fetch argo NAT IP for dev/prod (authorized to access GKE masters)
if [[ "${COMPONENT}" == "dev" || "${COMPONENT}" == "prod" ]] && [[ -z "${TF_VAR_argo_nat_ip:-}" ]]; then
  ARGO_DIR="${REPO_ROOT}/envs/argo"
  echo "==> Fetching argo NAT IP from argo terraform state..."
  TF_VAR_argo_nat_ip=$(terraform -chdir="${ARGO_DIR}" output -raw nat_external_ip 2>/dev/null || true)
  if [[ -z "${TF_VAR_argo_nat_ip}" ]]; then
    echo "ERROR: Could not fetch argo NAT IP. Deploy argo environment first."
    exit 1
  fi
  export TF_VAR_argo_nat_ip
  echo "==> Using argo NAT IP: ${TF_VAR_argo_nat_ip}"
fi

echo "==> Deploying: ${COMPONENT} (${DIR})"
cd "${TARGET}"

terraform init -upgrade
terraform plan -out=tfplan

echo ""
read -r -p "==> Apply the plan? [y/N] " CONFIRM
if [[ "${CONFIRM}" =~ ^[Yy]$ ]]; then
  terraform apply tfplan
  echo "==> ${COMPONENT} deployed successfully."
else
  echo "==> Aborted."
fi

rm -f tfplan
