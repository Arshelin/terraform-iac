output "dev_registry_url" {
  description = "Dev Docker registry URL"
  value       = module.artifact_registry_dev.repository_url
}

output "prod_registry_url" {
  description = "Prod Docker registry URL"
  value       = module.artifact_registry_prod.repository_url
}

output "cloud_build_dev_trigger_names" {
  description = "Cloud Build dev trigger names by app"
  value       = module.cloud_build.dev_trigger_names
}

output "cloud_build_prod_trigger_names" {
  description = "Cloud Build prod trigger names by app"
  value       = module.cloud_build.prod_trigger_names
}

output "cloud_build_sa_email" {
  description = "Cloud Build service account email"
  value       = module.cloud_build.service_account_email
}
