output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "VPC network self link"
  value       = google_compute_network.main.self_link
}

output "subnet_self_link" {
  description = "GKE subnet self link"
  value       = google_compute_subnetwork.gke.self_link
}

output "subnet_name" {
  description = "GKE subnet name"
  value       = google_compute_subnetwork.gke.name
}

output "pods_range_name" {
  description = "Secondary IP range name for GKE pods"
  value       = "pods"
}

output "services_range_name" {
  description = "Secondary IP range name for GKE services"
  value       = "services"
}

output "private_services_connection" {
  description = "Private services connection (Cloud SQL dependency)"
  value       = google_service_networking_connection.private_services.id
}

output "nat_external_ip" {
  description = "Cloud NAT static external IP address"
  value       = google_compute_address.nat.address
}
