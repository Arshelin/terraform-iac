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
