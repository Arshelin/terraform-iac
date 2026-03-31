resource "random_id" "db_suffix" {
  byte_length = 4
}

# ──────────────────────────────────────────────
# Cloud SQL – PostgreSQL 15 with HA
# ──────────────────────────────────────────────
resource "google_sql_database_instance" "main" {
  name             = "${var.environment}-postgres-${random_id.db_suffix.hex}"
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_15"

  deletion_protection = false

  settings {
    tier              = var.db_tier
    availability_type = var.availability_type

    disk_autoresize       = true
    disk_autoresize_limit = 100
    disk_size             = 20
    disk_type             = "PD_HDD"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "02:00"  # 2am UTC
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 14
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false   # no public IP
      private_network = var.network_self_link
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    maintenance_window {
      day          = 7   # Sunday
      hour         = 3   # 3am UTC
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    user_labels = var.labels
  }
}

# ──────────────────────────────────────────────
# Database and user
# ──────────────────────────────────────────────
resource "google_sql_database" "main" {
  name     = var.db_name
  project  = var.project_id
  instance = google_sql_database_instance.main.name
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "main" {
  name     = var.db_user
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result

  # Prevent accidental deletion of user
  lifecycle {
    ignore_changes = [password]
  }
}

# ──────────────────────────────────────────────
# Store DB password in Secret Manager
# ──────────────────────────────────────────────
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.environment}-db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}
