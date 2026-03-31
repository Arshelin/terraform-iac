#!/usr/bin/env bash
# eso-install.sh – install External Secrets Operator on dev/prod GKE clusters
# Prerequisites: helm installed, kubectl contexts for dev/prod clusters
# Usage: ./scripts/eso-install.sh [dev|prod|all]
set -euo pipefail

readonly ESO_VERSION="0.17.0"
readonly ESO_NS="external-secrets"

ENVS=()
case "${1:-all}" in
  dev)  ENVS=("dev") ;;
  prod) ENVS=("prod") ;;
  all)  ENVS=("dev" "prod") ;;
  *)
    echo "Usage: $0 [dev|prod|all]"
    exit 1
    ;;
esac

# ── Resolve cluster contexts ─────────────────────────────────────────────────
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
  echo "==> [error] No active GCP project. Run: gcloud config set project <PROJECT_ID>"
  exit 1
fi

get_context() {
  local env="$1"
  echo "gke_${PROJECT_ID}_europe-central2-a_${env}-global-cluster-0"
}

# ── Helm repo ────────────────────────────────────────────────────────────────
echo "==> Adding External Secrets Helm repository"
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# ── Install on each cluster ──────────────────────────────────────────────────
for ENV in "${ENVS[@]}"; do
  CTX=$(get_context "$ENV")

  echo ""
  echo "==> Installing External Secrets Operator on ${ENV} (context: ${CTX})"

  # Ensure credentials are available
  if ! kubectl --context "$CTX" cluster-info &>/dev/null; then
    echo "    Fetching credentials for ${ENV} cluster..."
    gcloud container clusters get-credentials "${ENV}-global-cluster-0" \
      --zone europe-central2-a --project "$PROJECT_ID"
  fi

  helm upgrade --install external-secrets \
    external-secrets/external-secrets \
    --kube-context "$CTX" \
    --namespace "$ESO_NS" \
    --create-namespace \
    --wait \
    --version "$ESO_VERSION" \
    --set installCRDs=true

  echo "==> External Secrets Operator installed on ${ENV}"
done

echo ""
echo "==> Done! ESO is ready on: ${ENVS[*]}"
echo ""
echo "Next steps:"
echo "  1. Apply Terraform IAM changes:  ./scripts/deploy.sh dev && ./scripts/deploy.sh prod"
echo "  2. ArgoCD will sync the Helm chart with SecretStore + ExternalSecret automatically"
