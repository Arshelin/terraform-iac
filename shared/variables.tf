variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "europe-central2"
}

variable "artifact_registry_repository_id" {
  description = "Artifact Registry Docker repository ID"
  type        = string
  default     = "webapp"
}

variable "github_owner" {
  description = "GitHub organization or user name"
  type        = string
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID (see README for setup instructions)"
  type        = number
}

variable "github_pat_token" {
  description = "GitHub Personal Access Token (pass via TF_VAR_github_pat_token env var)"
  type        = string
  sensitive   = true
}

variable "helm_charts_repo" {
  description = "GitHub repository name for Helm charts"
  type        = string
  default     = "helm-charts"
}
