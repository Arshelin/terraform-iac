project_id                      = "project-77fd6584-9134-4b27-9b1"
region                          = "europe-central2"
artifact_registry_repository_id = "webapp"

# GitHub – update before running terraform apply
github_owner               = "Arshelin"
github_app_installation_id = 119022745
helm_charts_repo           = "helm-charts"

# github_pat_token – do NOT put here; pass via env var:
#   export TF_VAR_github_pat_token="ghp_..."
