# ──────────────────────────────────────────────
# GKE Node Service Account
# ──────────────────────────────────────────────
resource "google_service_account" "gke_nodes" {
  account_id   = "prod-gke-nodes-sa"
  display_name = "GKE Node Pool Service Account (prod)"
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
# Webapp Service Account (Workload Identity)
# ──────────────────────────────────────────────
resource "google_service_account" "webapp" {
  account_id   = "prod-webapp-sa"
  display_name = "Web Application Service Account (prod)"
  project      = var.project_id
}

resource "google_project_iam_member" "webapp_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.webapp.email}"
}

resource "google_project_iam_member" "webapp_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.webapp.email}"
}

resource "google_project_iam_member" "webapp_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.webapp.email}"
}

resource "google_service_account_iam_member" "webapp_workload_identity" {
  service_account_id = google_service_account.webapp.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[spring-boot-api/spring-boot-api]"
  depends_on         = [module.gke]
}
