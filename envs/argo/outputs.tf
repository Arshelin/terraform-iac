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

output "gke_nodes_sa_email" {
  description = "GKE node pool service account email"
  value       = google_service_account.gke_nodes.email
}

output "argocd_sa_email" {
  description = "ArgoCD service account email"
  value       = google_service_account.argocd.email
}

output "network_name" {
  description = "VPC network name"
  value       = module.networking.network_name
}

output "argocd_lb_ip" {
  description = "Static regional IP for ArgoCD LoadBalancer"
  value       = google_compute_address.argocd_lb.address
}

output "nat_external_ip" {
  description = "Argo NAT external IP (use in dev/prod master_authorized_networks)"
  value       = module.networking.nat_external_ip
}
