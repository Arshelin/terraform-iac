output "repository_url" {
  description = "Docker repository URL for use in image tags"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}
