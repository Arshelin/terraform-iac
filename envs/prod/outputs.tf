output "gke_cluster_names" {
  description = "GKE cluster names by index"
  value       = { for k, v in module.gke : k => v.cluster_name }
}

output "gke_cluster_endpoints" {
  description = "GKE cluster API endpoints by index"
  value       = { for k, v in module.gke : k => v.cluster_endpoint }
  sensitive   = true
}

output "gke_get_credentials_cmds" {
  description = "Commands to configure kubectl per cluster"
  value = {
    for k, v in module.gke : k =>
    "gcloud container clusters get-credentials ${v.cluster_name} --region ${var.region} --project ${var.project_id}"
  }
}

output "waf_security_policy_name" {
  description = "Cloud Armor webapp policy name"
  value       = module.waf.security_policy_name
}

output "database_connection_name" {
  description = "Cloud SQL connection name (for Cloud SQL Auth Proxy)"
  value       = module.database.connection_name
}

output "database_private_ip" {
  description = "Cloud SQL private IP"
  value       = module.database.private_ip
  sensitive   = true
}

output "gke_nodes_sa_email" {
  description = "GKE node pool service account email"
  value       = google_service_account.gke_nodes.email
}

output "webapp_sa_email" {
  description = "Webapp service account email"
  value       = google_service_account.webapp.email
}

output "network_name" {
  description = "VPC network name"
  value       = module.networking.network_name
}

output "webapp_lb_ip" {
  description = "Static global IP for GKE Ingress L7 load balancer"
  value       = google_compute_global_address.webapp_lb.address
}
