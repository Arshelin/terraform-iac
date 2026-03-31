variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Build resources"
  type        = string
}

variable "labels" {
  description = "Common resource labels"
  type        = map(string)
  default     = {}
}

variable "github_owner" {
  description = "GitHub organization or user name"
  type        = string
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID (obtained after installing the Cloud Build GitHub App)"
  type        = number
}

variable "github_pat_token" {
  description = "GitHub Personal Access Token used for Cloud Build connection authorization"
  type        = string
  sensitive   = true
}

variable "helm_charts_repo" {
  description = "GitHub repository name for Helm charts"
  type        = string
  default     = "helm-charts"
}

variable "apps" {
  description = "Map of applications to create Cloud Build triggers for"
  type = map(object({
    github_repo       = string
    image_name        = string
    dev_registry_url  = string
    prod_registry_url = string
    included_files    = list(string)
  }))
}
