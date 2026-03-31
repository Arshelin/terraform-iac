# ──────────────────────────────────────────────
# GKE Node Service Account
# ──────────────────────────────────────────────
resource "google_service_account" "gke_nodes" {
  account_id   = "argo-gke-nodes-sa"
  display_name = "GKE Node Pool Service Account (argo)"
  project      = var.project_id
}

resource "google_project_iam_member" "gke_nodes_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
    "roles/storage.objectViewer",
    "roles/container.defaultNodeServiceAccount",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ──────────────────────────────────────────────
# ArgoCD Service Account (Workload Identity)
# ──────────────────────────────────────────────
resource "google_service_account" "argocd" {
  account_id   = "argo-argocd-sa"
  display_name = "ArgoCD Service Account (Workload Identity)"
  project      = var.project_id
}

resource "google_project_iam_member" "argocd_roles" {
  for_each = toset([
    "roles/container.admin",  # manage workloads on dev/prod clusters
    "roles/storage.admin",    # access Helm charts and OCI repos
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.argocd.email}"
}

# Workload Identity bindings – all ArgoCD components that need GCP access
resource "google_service_account_iam_member" "argocd_workload_identity" {
  for_each = toset([
    "argocd/argocd-server",
    "argocd/argocd-application-controller",
    "argocd/argocd-repo-server",
  ])
  service_account_id = google_service_account.argocd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value}]"
  depends_on         = [module.gke]
}
