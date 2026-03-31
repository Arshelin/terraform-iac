#!/usr/bin/env bash
# argocd-add-clusters.sh – deploy the argocd-clusters Helm chart
# Registers dev/prod GKE clusters in ArgoCD via Workload Identity secrets.
# Prerequisites: kubectl configured for argo cluster
# Usage: ./scripts/argocd-add-clusters.sh
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
readonly REPO_ROOT
readonly ARGOCD_NS="argocd"
readonly CHART_DIR="${REPO_ROOT}/k8s/argocd-clusters"

echo "==> Installing argocd-clusters chart"
helm upgrade --install argocd-clusters "$CHART_DIR" \
  --namespace "$ARGOCD_NS" \
  --wait \
  --atomic

echo ""
echo "==> Clusters registered. Verify in ArgoCD UI: Settings > Clusters"
echo ""
helm list -n "$ARGOCD_NS"
