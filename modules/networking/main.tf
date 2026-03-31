# ──────────────────────────────────────────────
# VPC Network
# ──────────────────────────────────────────────
resource "google_compute_network" "main" {
  name                    = "${var.environment}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# ──────────────────────────────────────────────
# Subnet with secondary ranges for GKE
# ──────────────────────────────────────────────
resource "google_compute_subnetwork" "gke" {
  name          = "${var.environment}-gke-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = var.subnet_cidr

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ──────────────────────────────────────────────
# Cloud Router + NAT (outbound internet for private nodes)
# ──────────────────────────────────────────────
resource "google_compute_router" "main" {
  name    = "${var.environment}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_address" "nat" {
  name         = "${var.environment}-nat-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.environment}-nat"
  project                            = var.project_id
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ──────────────────────────────────────────────
# Firewall Rules
# ──────────────────────────────────────────────

# Allow internal traffic within the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-allow-internal"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
  priority      = 1000
}

# Allow health checks from GCP load balancers
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.environment}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
  }

  # GCP health check source ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22", "209.85.152.0/22", "209.85.204.0/22"]
  priority      = 1000
}

# Allow GKE master to reach nodes (webhooks, metrics)
resource "google_compute_firewall" "allow_master_to_nodes" {
  name    = "${var.environment}-allow-master-to-nodes"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["443", "8443", "10250"]
  }

  source_ranges = [var.master_cidr]
  target_tags   = ["gke-node"]
  priority      = 1000
}

# ──────────────────────────────────────────────
# Private Service Access (for Cloud SQL)
# ──────────────────────────────────────────────
resource "google_compute_global_address" "private_services" {
  name          = "${var.environment}-private-services-ip"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}
