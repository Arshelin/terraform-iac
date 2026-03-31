variable "project_id" {
  description = "GCP Project ID"
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

variable "rate_limit_threshold_count" {
  description = "Max requests per IP within the interval"
  type        = number
  default     = 1000
}

variable "rate_limit_threshold_interval_sec" {
  description = "Rate limit window in seconds"
  type        = number
  default     = 60
}

variable "enable_webapp_policy" {
  description = "Create Cloud Armor policy for web application (prod/dev)"
  type        = bool
  default     = true
}

variable "enable_argocd_policy" {
  description = "Create Cloud Armor policy for ArgoCD (argo workspace)"
  type        = bool
  default     = false
}
