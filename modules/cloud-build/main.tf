data "google_project" "project" {
  project_id = var.project_id
}

# ──────────────────────────────────────────────
# Service Account for Cloud Build
# ──────────────────────────────────────────────
resource "google_service_account" "cloud_build" {
  project      = var.project_id
  account_id   = "cloud-build-sa"
  display_name = "Cloud Build – CI/CD pipeline"
}

resource "google_project_iam_member" "cloud_build_roles" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/logging.logWriter",
    "roles/storage.admin",
    "roles/cloudbuild.builds.builder",
    "roles/ondemandscanning.admin",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Allow the Cloud Build service agent to impersonate the custom SA
resource "google_service_account_iam_member" "cloud_build_agent" {
  service_account_id = google_service_account.cloud_build.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

# ──────────────────────────────────────────────
# GitHub PAT – stored in Secret Manager
# ──────────────────────────────────────────────
resource "google_secret_manager_secret" "github_pat" {
  project   = var.project_id
  secret_id = "github-pat-cloudbuild"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_pat" {
  secret      = google_secret_manager_secret.github_pat.id
  secret_data = var.github_pat_token
}

resource "google_secret_manager_secret_iam_member" "cloud_build_secret" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.github_pat.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_build.email}"
}

# The Cloud Build service agent needs access to the secret for v2 connections/repositories
resource "google_secret_manager_secret_iam_member" "cloud_build_agent_secret" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.github_pat.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

# ──────────────────────────────────────────────
# Cloud Build v2 – GitHub connection
# ──────────────────────────────────────────────
resource "google_cloudbuildv2_connection" "github" {
  project  = var.project_id
  location = var.region
  name     = "github-connection"

  github_config {
    app_installation_id = var.github_app_installation_id
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github_pat.id
    }
  }
}

# ──────────────────────────────────────────────
# Repositories – one per app + helm-charts
# ──────────────────────────────────────────────
resource "google_cloudbuildv2_repository" "apps" {
  for_each = var.apps

  project           = var.project_id
  location          = var.region
  name              = each.value.github_repo
  parent_connection = google_cloudbuildv2_connection.github.id
  remote_uri        = "https://github.com/${var.github_owner}/${each.value.github_repo}.git"
}

resource "google_cloudbuildv2_repository" "helm_charts" {
  project           = var.project_id
  location          = var.region
  name              = var.helm_charts_repo
  parent_connection = google_cloudbuildv2_connection.github.id
  remote_uri        = "https://github.com/${var.github_owner}/${var.helm_charts_repo}.git"
}

# ──────────────────────────────────────────────
# DEV Triggers – push to main
# ──────────────────────────────────────────────
# Image tags: {SHORT_SHA} + latest
# ArgoCD Image Updater monitors the "latest" digest and syncs automatically.

resource "google_cloudbuild_trigger" "dev" {
  for_each = var.apps

  project  = var.project_id
  location = var.region
  name     = "${each.key}-dev"

  service_account = google_service_account.cloud_build.id

  repository_event_config {
    repository = google_cloudbuildv2_repository.apps[each.key].id
    push {
      branch = "^main$"
    }
  }

  included_files = each.value.included_files

  substitutions = {
    _DEV_REGISTRY_URL = each.value.dev_registry_url
    _IMAGE_NAME       = each.value.image_name
    _APP_NAME         = each.key
    _GITHUB_OWNER     = var.github_owner
    _GITHUB_REPO      = each.value.github_repo
  }

  build {
    # ── 1. Build Docker image ──
    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "build"
      args = [
        "build",
        "--file=Dockerfile",
        "--tag=$_DEV_REGISTRY_URL/$_IMAGE_NAME:$SHORT_SHA",
        "--tag=$_DEV_REGISTRY_URL/$_IMAGE_NAME:latest",
        "--cache-from=$_DEV_REGISTRY_URL/$_IMAGE_NAME:latest",
        ".",
      ]
    }

    # ── 2. Push both tags to dev Artifact Registry ──
    step {
      name = "gcr.io/cloud-builders/docker"
      id   = "push"
      args = ["push", "--all-tags", "$_DEV_REGISTRY_URL/$_IMAGE_NAME"]
    }

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}

# ──────────────────────────────────────────────
# PROD Triggers – push to release/*
# ──────────────────────────────────────────────
# Flow: extract version → build → push → vuln scan → tag app → update helm-charts → ArgoCD syncs

resource "google_cloudbuild_trigger" "prod" {
  for_each = var.apps

  project  = var.project_id
  location = var.region
  name     = "${each.key}-prod"

  service_account = google_service_account.cloud_build.id

  repository_event_config {
    repository = google_cloudbuildv2_repository.apps[each.key].id
    push {
      branch = "^release/.*$"
    }
  }

  substitutions = {
    _PROD_REGISTRY_URL = each.value.prod_registry_url
    _IMAGE_NAME        = each.value.image_name
    _APP_NAME          = each.key
    _GITHUB_OWNER      = var.github_owner
    _GITHUB_REPO       = each.value.github_repo
    _HELM_CHARTS_REPO  = var.helm_charts_repo
    _BRANCH_NAME       = "$BRANCH_NAME"
  }

  build {
    # ── 1. Extract version from branch name ──
    step {
      name       = "gcr.io/cloud-builders/gcloud"
      id         = "extract-version"
      entrypoint = "bash"
      args = ["-c", <<-EOT
        BRANCH="$_BRANCH_NAME"
        echo "==> Extracting version from branch name: $$${BRANCH}"
        VERSION="$$${BRANCH#release/}"
        echo "$$${VERSION}" > /workspace/version.txt
        echo "==> Release version: $$${VERSION}"
      EOT
      ]
    }

    # ── 2. Build Docker image ──
    step {
      name       = "gcr.io/cloud-builders/docker"
      id         = "build"
      entrypoint = "bash"
      wait_for   = ["extract-version"]
      args = ["-c", <<-EOT
        VERSION=$(cat /workspace/version.txt)
        docker build \
          --file=Dockerfile \
          --tag=$_PROD_REGISTRY_URL/$_IMAGE_NAME:$$${VERSION} \
          .
      EOT
      ]
    }

    # ── 3. Push image (needed for on-demand scanning) ──
    step {
      name       = "gcr.io/cloud-builders/docker"
      id         = "push"
      entrypoint = "bash"
      wait_for   = ["build"]
      args = ["-c", <<-EOT
        VERSION=$(cat /workspace/version.txt)
        docker push $_PROD_REGISTRY_URL/$_IMAGE_NAME:$$${VERSION}
      EOT
      ]
    }

    # ── 4. Vulnerability scan ──
    step {
      name       = "gcr.io/cloud-builders/gcloud"
      id         = "vuln-scan"
      entrypoint = "bash"
      wait_for   = ["push"]
      args = ["-c", <<-EOT
        VERSION=$(cat /workspace/version.txt)
        IMAGE="$_PROD_REGISTRY_URL/$_IMAGE_NAME:$$${VERSION}"

        echo "==> Running vulnerability scan on $$${IMAGE}..."
        SCAN_OUTPUT=$(gcloud artifacts docker images scan "$$${IMAGE}" \
          --remote \
          --format='value(response.scan)')

        if [ -z "$$${SCAN_OUTPUT}" ]; then
          echo "ERROR: Scan failed to produce results"
          exit 1
        fi

        echo "==> Checking for CRITICAL and HIGH vulnerabilities..."
        VULN_COUNT=$(gcloud artifacts docker images list-vulnerabilities "$$${SCAN_OUTPUT}" \
          --format='value(vulnerability.effectiveSeverity)' \
          | grep -cE 'CRITICAL|HIGH' || true)

        echo "==> Found $$${VULN_COUNT} CRITICAL/HIGH vulnerabilities"

        if [ "$$${VULN_COUNT}" -gt 0 ]; then
          echo "ERROR: Image has $$${VULN_COUNT} CRITICAL/HIGH vulnerabilities. Blocking release."
          gcloud artifacts docker images list-vulnerabilities "$$${SCAN_OUTPUT}" \
            --format='table(vulnerability.effectiveSeverity, vulnerability.shortDescription, vulnerability.packageIssue.affectedPackage)'
          exit 1
        fi

        echo "==> Scan passed — no CRITICAL/HIGH vulnerabilities found"
      EOT
      ]
    }

    # ── 5. Tag app repo ──
    step {
      name       = "gcr.io/cloud-builders/git"
      id         = "tag-app"
      entrypoint = "bash"
      wait_for   = ["vuln-scan"]
      secret_env = ["GITHUB_TOKEN"]
      args = ["-c", <<-EOT
        VERSION=$(cat /workspace/version.txt)

        git config user.email "cloud-build@$${PROJECT_ID}.iam.gserviceaccount.com"
        git config user.name "Cloud Build"
        git remote set-url origin https://x-access-token:$$GITHUB_TOKEN@github.com/$_GITHUB_OWNER/$_GITHUB_REPO.git

        git tag -a "$_APP_NAME-$$${VERSION}" -m "Release $_APP_NAME-$$${VERSION}"
        git push origin "$_APP_NAME-$$${VERSION}"

        echo "==> Tagged $_GITHUB_REPO as $_APP_NAME-$$${VERSION}"
      EOT
      ]
    }

    # ── 6. Update helm-charts: bump prod image tag, commit, tag ──
    step {
      name       = "gcr.io/cloud-builders/git"
      id         = "update-helm-charts"
      entrypoint = "bash"
      wait_for   = ["tag-app"]
      secret_env = ["GITHUB_TOKEN"]
      args = ["-c", <<-EOT
        VERSION=$(cat /workspace/version.txt)

        git clone https://x-access-token:$$GITHUB_TOKEN@github.com/$_GITHUB_OWNER/$_HELM_CHARTS_REPO.git /workspace/helm-charts
        cd /workspace/helm-charts

        git config user.email "cloud-build@$${PROJECT_ID}.iam.gserviceaccount.com"
        git config user.name "Cloud Build"

        sed -i "s|  tag:.*|  tag: \"$$${VERSION}\"|" $_APP_NAME/values/prod.yaml

        git add $_APP_NAME/values/prod.yaml
        git commit -m "ci(prod): $_APP_NAME $$${VERSION} — image $_PROD_REGISTRY_URL/$_IMAGE_NAME:$$${VERSION}"

        git tag -a "$$${VERSION}" -m "Prod release $$${VERSION}"

        git push origin main --tags

        echo "==> $_HELM_CHARTS_REPO updated and tagged as $$${VERSION}"
      EOT
      ]
    }

    available_secrets {
      secret_manager {
        env          = "GITHUB_TOKEN"
        version_name = "projects/${data.google_project.project.number}/secrets/${google_secret_manager_secret.github_pat.secret_id}/versions/latest"
      }
    }

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}
