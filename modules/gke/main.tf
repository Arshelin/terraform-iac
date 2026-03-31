locals {
  location = var.cluster_location != "" ? var.cluster_location : var.region
}

# ──────────────────────────────────────────────
# GKE Cluster (regional or zonal)
# ──────────────────────────────────────────────
resource "google_container_cluster" "main" {
  provider = google-beta

  name     = var.cluster_name
  project  = var.project_id
  location = local.location

  deletion_protection = false # It is only for testing purpose

  # Managed node pool – remove default node pool immediately
  remove_default_node_pool = true
  initial_node_count       = 1

  # Use pd-balanced for the temporary default pool to avoid SSD quota issues
  node_config {
    disk_type    = "pd-balanced"
    disk_size_gb = 30
  }

  network    = var.network_self_link
  subnetwork = var.subnet_self_link

  # Private cluster – nodes have no public IPs
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    master_global_access_config {
      enabled = true
    }
  }

  # Restrict who can reach the master endpoint
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_cidr_blocks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_cidr_blocks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # VPC-native networking (alias IPs)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Master auth – disable basic auth and client cert
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  # Network policy (Calico)
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Logging & monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  release_channel {
    channel = "REGULAR"
  }

  resource_labels = var.labels

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

# ──────────────────────────────────────────────
# Primary Node Pool
# 1 node per zone (3 zones) = 3 workers
# ──────────────────────────────────────────────
resource "google_container_node_pool" "primary" {
  name       = "${var.cluster_name}-primary-pool"
  project    = var.project_id
  location   = local.location
  cluster    = google_container_cluster.main.name

  # Pin to specific zones for deterministic placement (not set for zonal clusters)
  node_locations = length(var.node_locations) > 0 ? var.node_locations : null

  node_count = var.min_nodes_per_zone

  # Autoscaling within each zone
  autoscaling {
    min_node_count = var.min_nodes_per_zone
    max_node_count = var.max_nodes_per_zone
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  node_config {
    machine_type = var.node_machine_type
    image_type   = "COS_CONTAINERD"

    disk_size_gb = var.node_disk_size_gb
    disk_type    = "pd-balanced"

    service_account = var.gke_sa_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    # Workload Identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = var.labels
    tags   = ["gke-node", var.cluster_name]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
