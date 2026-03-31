variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "labels" {
  description = "Common resource labels"
  type        = map(string)
  default     = {}
}

variable "network_self_link" {
  description = "VPC network self link for private IP"
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "webapp"
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "webapp_admin"
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-g1-small"
}

variable "availability_type" {
  description = "Cloud SQL availability type: REGIONAL (HA) or ZONAL"
  type        = string
  default     = "ZONAL"
}
