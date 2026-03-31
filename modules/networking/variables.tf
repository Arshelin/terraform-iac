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

variable "subnet_cidr" {
  description = "Primary CIDR for the GKE subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE pods"
  type        = string
  default     = "10.48.0.0/18"
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE services"
  type        = string
  default     = "10.20.0.0/18"
}

variable "master_cidr" {
  description = "CIDR for GKE master (used in firewall rules)"
  type        = string
  default     = "172.16.0.0/28"
}
