provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  environment = "argo"

  zone               = "${var.region}-a"  # single-zone cluster
  node_machine_type  = "e2-standard-4"
  node_disk_size_gb  = 20
  min_nodes_per_zone = 1
  max_nodes_per_zone = 1

  common_labels = {
    project     = var.project_id
    environment = local.environment
    managed_by  = "terraform"
  }
}

# ──────────────────────────────────────────────
# Enable required GCP APIs
# ──────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# Networking
# ──────────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  project_id    = var.project_id
  region        = var.region
  environment   = local.environment
  labels        = local.common_labels
  subnet_cidr   = "10.0.0.0/20"
  pods_cidr     = "10.48.0.0/18"
  services_cidr = "10.20.0.0/18"
  master_cidr   = "172.16.0.0/28"

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────
# GKE Cluster
# ──────────────────────────────────────────────
module "gke" {
  for_each = { for c in var.clusters : tostring(c.index) => c }
  source   = "../../modules/gke"

  project_id          = var.project_id
  region              = var.region
  cluster_location    = local.zone
  environment         = local.environment
  labels              = local.common_labels
  cluster_name        = "${local.environment}-global-cluster-${each.key}"
  network_self_link   = module.networking.network_self_link
  subnet_self_link    = module.networking.subnet_self_link
  pods_range_name     = module.networking.pods_range_name
  services_range_name = module.networking.services_range_name
  gke_sa_email        = google_service_account.gke_nodes.email

  node_machine_type  = local.node_machine_type
  node_disk_size_gb  = local.node_disk_size_gb
  min_nodes_per_zone = local.min_nodes_per_zone
  max_nodes_per_zone = local.max_nodes_per_zone

  depends_on = [module.networking, google_project_service.apis]
}

# ──────────────────────────────────────────────
# Static regional IP for ArgoCD LoadBalancer
# ──────────────────────────────────────────────
resource "google_compute_address" "argocd_lb" {
  name         = "argocd-lb-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"

  depends_on = [google_project_service.apis]
}
