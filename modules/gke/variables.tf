variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region (cluster location)"
  type        = string
}

variable "zones" {
  description = "List of zones for node placement. Not used for zonal clusters (see node_locations)."
  type        = list(string)
  default     = []
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

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "network_self_link" {
  description = "VPC network self link"
  type        = string
}

variable "subnet_self_link" {
  description = "Subnet self link"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
}

variable "gke_sa_email" {
  description = "Service account email for GKE nodes"
  type        = string
}

variable "node_machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "node_disk_size_gb" {
  description = "Boot disk size per node in GB"
  type        = number
  default     = 30
}

variable "cluster_location" {
  description = "Cluster location: region (multi-zone) or zone (single-zone). Defaults to var.region."
  type        = string
  default     = ""
}

variable "node_locations" {
  description = "Zones for node placement. Leave empty for zonal clusters."
  type        = list(string)
  default     = []
}

variable "min_nodes_per_zone" {
  description = "Minimum number of nodes per zone (autoscaling lower bound)"
  type        = number
  default     = 1
}

variable "max_nodes_per_zone" {
  description = "Maximum number of nodes per zone (autoscaling upper bound)"
  type        = number
  default     = 3
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master (private cluster)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_cidr_blocks" {
  description = "List of CIDR blocks authorized to access the GKE master endpoint"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}
