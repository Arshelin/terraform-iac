variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "repository_id" {
  type = string
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = "Docker image repository"
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "cleanup_policy_days" {
  description = "Delete images older than N days. Set to null to disable cleanup."
  type        = number
  default     = null
}

variable "cleanup_keep_count" {
  description = "Always keep at least N most recent versions, even if older than cleanup_policy_days"
  type        = number
  default     = 5
}

variable "enable_vulnerability_scanning" {
  description = "Enable automatic container vulnerability scanning for this repository"
  type        = bool
  default     = false
}
