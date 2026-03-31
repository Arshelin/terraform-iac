#!/usr/bin/env bash
# bootstrap.sh – one-time setup before first `terraform apply`
# Usage: ./scripts/bootstrap.sh <PROJECT_ID> <BUCKET_NAME> [REGION]
set -euo pipefail

export PROJECT_ID="${1:?Usage: $0 <PROJECT_ID> <STATE_BUCKET_NAME> [REGION]}"
export STATE_BUCKET="${2:?Usage: $0 <PROJECT_ID> <STATE_BUCKET_NAME> [REGION]}"
export REGION="${3:-europe-central2}"

readonly REQUIRED_APIS=(
  cloudresourcemanager.googleapis.com
  storage.googleapis.com
  iam.googleapis.com
  secretmanager.googleapis.com
)

function check_tool() {
  command -v "${1}" &>/dev/null || { echo "==> Missing tool: ${1}"; exit 1; }
}

function ensure_api() {
  local api="${1}"
  local result
  result=$(gcloud services list --enabled --filter="name:${api}" --format="value(name)" 2>/dev/null)
  if [[ "$result" == *"$api"* ]]; then
    echo "    [ok] ${api}"
  else
    echo "    [enabling] ${api}"
    gcloud services enable "${api}" --project="${PROJECT_ID}"
  fi
}

check_tool gcloud
check_tool terraform

echo "==> Setting GCP project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

echo "==> Verifying required APIs..."
for api in "${REQUIRED_APIS[@]}"; do
  ensure_api "${api}"
done

echo "==> Creating Terraform state bucket: gs://${STATE_BUCKET}"
if ! gcloud storage buckets describe "gs://${STATE_BUCKET}" --project "${PROJECT_ID}" &>/dev/null; then
  gcloud storage buckets create "gs://${STATE_BUCKET}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --uniform-bucket-level-access
  gcloud storage buckets update "gs://${STATE_BUCKET}" \
    --project="${PROJECT_ID}" \
    --versioning
  echo "    Bucket created."
else
  echo "    Bucket already exists, skipping."
fi

echo ""
echo "==> Storing GitHub PAT in Secret Manager..."
SECRET_ID="github-pat-terraform"
if gcloud secrets describe "${SECRET_ID}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "    Secret '${SECRET_ID}' already exists."
  read -r -p "    Overwrite with a new token? [y/N] " OVERWRITE
  if [[ "${OVERWRITE}" =~ ^[Yy]$ ]]; then
    read -r -s -p "    Enter GitHub PAT: " GITHUB_PAT
    echo ""
    echo -n "${GITHUB_PAT}" | gcloud secrets versions add "${SECRET_ID}" \
      --data-file=- --project="${PROJECT_ID}"
    echo "    Secret updated."
  else
    echo "    Keeping existing secret."
  fi
else
  read -r -s -p "    Enter GitHub PAT (used by Terraform for Cloud Build): " GITHUB_PAT
  echo ""
  echo -n "${GITHUB_PAT}" | gcloud secrets create "${SECRET_ID}" \
    --data-file=- --replication-policy=automatic --project="${PROJECT_ID}"
  echo "    Secret created."
fi

echo ""
echo "==> Updating backend bucket name in all versions.tf files..."
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
for dir in shared envs/dev envs/prod envs/argo; do
  FILE="${REPO_ROOT}/${dir}/versions.tf"
  if [[ -f "$FILE" ]]; then
    sed -i "s|bucket = \".*\"|bucket = \"${STATE_BUCKET}\"|" "$FILE"
    echo "    Updated: ${dir}/versions.tf"
  fi
done

echo ""
echo "==> Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Edit shared/terraform.tfvars  (set GitHub owner, installation ID)"
echo "  2. ./scripts/deploy.sh shared    (Artifact Registry + Cloud Build)"
echo "  3. ./scripts/deploy.sh dev       (or prod, argo)"
