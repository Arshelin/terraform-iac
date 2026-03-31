output "dev_trigger_names" {
  description = "Cloud Build dev trigger names by app"
  value       = { for k, v in google_cloudbuild_trigger.dev : k => v.name }
}

output "prod_trigger_names" {
  description = "Cloud Build prod trigger names by app"
  value       = { for k, v in google_cloudbuild_trigger.prod : k => v.name }
}

output "service_account_email" {
  description = "Cloud Build service account email"
  value       = google_service_account.cloud_build.email
}

output "github_connection_name" {
  description = "Cloud Build v2 GitHub connection name"
  value       = google_cloudbuildv2_connection.github.name
}

output "helm_charts_repository_name" {
  description = "Cloud Build v2 helm-charts repository name"
  value       = google_cloudbuildv2_repository.helm_charts.name
}
