provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  environment = "prod"

  zone               = "${var.region}-a"  # single-zone cluster
  node_machine_type  = "e2-standard-4"
  node_disk_size_gb  = 20
  min_nodes_per_zone = 1
  max_nodes_per_zone = 1
  db_tier            = "db-g1-small"
  db_availability    = "REGIONAL"
  waf_rate_limit     = 1000

  # Multi-zone:
  # zones              = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]
  # min_nodes_per_zone = 2
  # max_nodes_per_zone = 6

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
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
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
  subnet_cidr   = "10.2.0.0/20"
  pods_cidr     = "10.50.0.0/18"
  services_cidr = "10.22.0.0/18"
  master_cidr   = "172.16.2.0/28"

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────
# GKE Clusters
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

  node_machine_type      = local.node_machine_type
  node_disk_size_gb      = local.node_disk_size_gb
  min_nodes_per_zone     = local.min_nodes_per_zone
  max_nodes_per_zone     = local.max_nodes_per_zone
  master_ipv4_cidr_block = "172.16.2.0/28"

  master_authorized_cidr_blocks = [
    { cidr_block = "${var.argo_nat_ip}/32", display_name = "argocd" },
    { cidr_block = "84.40.153.197/32", display_name = "arsh-local" },
  ]

  depends_on = [module.networking, google_project_service.apis]
}

# ──────────────────────────────────────────────
# WAF – Cloud Armor
# ──────────────────────────────────────────────
module "waf" {
  source = "../../modules/waf"

  project_id  = var.project_id
  environment = local.environment
  labels      = local.common_labels

  rate_limit_threshold_count        = local.waf_rate_limit
  rate_limit_threshold_interval_sec = 60
  enable_webapp_policy              = true
  enable_argocd_policy              = false

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────
# Static global IP for GKE Ingress (L7 LB)
# ──────────────────────────────────────────────
resource "google_compute_global_address" "webapp_lb" {
  name         = "prod-webapp-lb-ip"
  project      = var.project_id
  address_type = "EXTERNAL"

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────
# Cloud SQL – PostgreSQL (REGIONAL HA)
# ──────────────────────────────────────────────
module "database" {
  source = "../../modules/database"

  project_id        = var.project_id
  region            = var.region
  environment       = local.environment
  labels            = local.common_labels
  network_self_link = module.networking.network_self_link
  db_name           = var.db_name
  db_user           = var.db_user
  db_tier           = local.db_tier
  availability_type = local.db_availability

  depends_on = [module.networking, google_project_service.apis]
}
