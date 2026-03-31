resource "google_artifact_registry_repository" "main" {
  repository_id = var.repository_id
  project       = var.project_id
  location      = var.region
  format        = "DOCKER"
  description   = var.description

  labels = var.labels

  # Cleanup policies — only created when provided
  dynamic "cleanup_policies" {
    for_each = var.cleanup_policy_days != null ? [1] : []
    content {
      id     = "delete-old-images"
      action = "DELETE"
      condition {
        older_than = "${var.cleanup_policy_days * 24 * 60 * 60}s"
      }
    }
  }

  dynamic "cleanup_policies" {
    for_each = var.cleanup_policy_days != null ? [1] : []
    content {
      id     = "keep-minimum-versions"
      action = "KEEP"
      most_recent_versions {
        keep_count = var.cleanup_keep_count
      }
    }
  }

  # Vulnerability scanning — enabled per repository via project-level config
  # Controlled by the enable_vulnerability_scanning variable for documentation
}

# ──────────────────────────────────────────────
# Enable On-Demand / Automatic scanning (project-level toggle)
# ──────────────────────────────────────────────
resource "google_project_service" "container_scanning" {
  count   = var.enable_vulnerability_scanning ? 1 : 0
  project = var.project_id
  service = "containerscanning.googleapis.com"

  disable_on_destroy = false
}
