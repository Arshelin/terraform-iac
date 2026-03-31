output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "connection_name" {
  description = "Cloud SQL connection name (used by Cloud SQL Auth Proxy)"
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.main.private_ip_address
  sensitive   = true
}

output "db_name" {
  description = "Database name"
  value       = google_sql_database.main.name
}

output "db_user" {
  description = "Database username"
  value       = google_sql_user.main.name
}

output "db_password_secret_id" {
  description = "Secret Manager secret ID for DB password"
  value       = google_secret_manager_secret.db_password.secret_id
}
