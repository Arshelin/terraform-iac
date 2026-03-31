#!/usr/bin/env bash
# argocd-install.sh – install ArgoCD on the argo GKE cluster
# Prerequisites: kubectl configured for argo cluster, helm installed
# Usage: ./scripts/argocd-install.sh
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
readonly REPO_ROOT
readonly ARGOCD_NS="argocd"
readonly ARGOCD_VERSION="7.3.4"
readonly K8S_DIR="${REPO_ROOT}/k8s/argocd"
readonly ARGO_TF_DIR="${REPO_ROOT}/envs/argo"

# ── Fetch Terraform outputs ──────────────────────────────────────────────────
STATIC_IP=$(terraform -chdir="$ARGO_TF_DIR" output -raw argocd_lb_ip 2>/dev/null || echo "")
readonly STATIC_IP
if [[ -z "$STATIC_IP" ]]; then
  echo "==> [error] Could not retrieve argocd_lb_ip from terraform output."
  echo "            Run: ./scripts/deploy.sh argo"
  exit 1
fi

ARGOCD_SA=$(terraform -chdir="$ARGO_TF_DIR" output -raw argocd_sa_email 2>/dev/null || echo "")
readonly ARGOCD_SA
if [[ -z "$ARGOCD_SA" ]]; then
  echo "==> [error] Could not retrieve argocd_sa_email from terraform output."
  exit 1
fi

# ── Helm install ──────────────────────────────────────────────────────────────
echo "==> Adding ArgoCD Helm repository"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "==> Installing ArgoCD ${ARGOCD_VERSION} (LB IP: ${STATIC_IP})"
helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NS" \
  --create-namespace \
  --wait \
  --atomic \
  --version "$ARGOCD_VERSION" \
  --values "${K8S_DIR}/values.yaml" \
  --set server.service.loadBalancerIP="${STATIC_IP}" \
  --set "server.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=${ARGOCD_SA}" \
  --set "controller.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=${ARGOCD_SA}" \
  --set "repoServer.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=${ARGOCD_SA}"

# ── Wait for LoadBalancer IP ──────────────────────────────────────────────────
echo "==> Waiting for LoadBalancer external IP..."
for _ in $(seq 1 30); do
  ADDR=$(kubectl get svc argocd-server -n "$ARGOCD_NS" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [[ -n "$ADDR" ]]; then break; fi
  sleep 5
done

if [[ -z "${ADDR:-}" ]]; then
  echo "==> [warn] LoadBalancer IP not yet assigned. Check: kubectl get svc -n argocd"
fi


### TODO Remove this, pass leaks into logs and is not needed for the workshop
# ── Summary ───────────────────────────────────────────────────────────────────
ADMIN_PASS=$(kubectl -n "$ARGOCD_NS" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "(not found)")

echo ""
echo "==> ArgoCD installed successfully!"
echo ""
echo "    URL:            http://${ADDR:-${STATIC_IP}}"
echo "    Admin user:     admin"
echo "    Admin password: ${ADMIN_PASS}"
echo ""
echo "Next steps:"
echo "  Register dev/prod clusters:"
echo "    ./scripts/argocd-add-clusters.sh dev"
echo "    ./scripts/argocd-add-clusters.sh prod"
