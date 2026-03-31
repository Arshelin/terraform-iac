provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  common_labels = {
    project    = var.project_id
    managed_by = "terraform"
    layer      = "shared"
  }
}

# ──────────────────────────────────────────────
# Enable required GCP APIs
# ──────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
    "ondemandscanning.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# Artifact Registry – DEV (7-day retention)
# ──────────────────────────────────────────────
module "artifact_registry_dev" {
  source = "../modules/artifact-registry"

  project_id          = var.project_id
  region              = var.region
  repository_id       = "${var.artifact_registry_repository_id}-dev"
  description         = "Development Docker images – 7-day cleanup policy"
  labels              = merge(local.common_labels, { environment = "dev" })
  cleanup_policy_days = 7
  cleanup_keep_count  = 5

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────
# Artifact Registry – PROD (no retention, vuln scanning)
# ──────────────────────────────────────────────
module "artifact_registry_prod" {
  source = "../modules/artifact-registry"

  project_id                    = var.project_id
  region                        = var.region
  repository_id                 = "${var.artifact_registry_repository_id}-prod"
  description                   = "Production Docker images – no deletion, vulnerability scanning enabled"
  labels                        = merge(local.common_labels, { environment = "prod" })
  enable_vulnerability_scanning = true

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────
# Cloud Build – CI pipelines (dev + prod triggers)
# ──────────────────────────────────────────────
module "cloud_build" {
  source = "../modules/cloud-build"

  project_id                 = var.project_id
  region                     = var.region
  labels                     = local.common_labels
  github_owner               = var.github_owner
  github_app_installation_id = var.github_app_installation_id
  github_pat_token           = var.github_pat_token
  helm_charts_repo           = var.helm_charts_repo

  apps = {
    spring-boot-api = {
      github_repo       = "spring-boot-api"
      image_name        = "webapp"
      dev_registry_url  = module.artifact_registry_dev.repository_url
      prod_registry_url = module.artifact_registry_prod.repository_url
      included_files = [
        "src/**",
        "pom.xml",
        "Dockerfile",
      ]
    }
    # To add another app:
    # another-api = {
    #   github_repo       = "another-api"
    #   image_name        = "another"
    #   dev_registry_url  = module.artifact_registry_dev.repository_url
    #   prod_registry_url = module.artifact_registry_prod.repository_url
    #   included_files    = ["src/**", "pom.xml", "Dockerfile", "cloudbuild.yaml"]
    # }
  }

  depends_on = [module.artifact_registry_dev, module.artifact_registry_prod, google_project_service.apis]
}
