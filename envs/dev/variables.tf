variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "europe-central2"
}

variable "clusters" {
  description = "List of GKE clusters to create"
  type = list(object({
    index = number
  }))
  default = [{ index = 0 }]
}

variable "argo_nat_ip" {
  description = "ArgoCD cluster NAT external IP (authorized to access GKE master)"
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "webapp"
}

variable "db_user" {
  description = "PostgreSQL master username"
  type        = string
  default     = "webapp_admin"
}
