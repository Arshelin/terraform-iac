# GCP Infrastructure – Terraform

GKE-based platform for a Java web application with ArgoCD-driven continuous delivery. Infrastructure is split into independent Terraform roots with separate state files.

## Repository structure

```
terraform-iac/
├── shared/            # Cross-cutting resources: Artifact Registry + Cloud Build CI/CD
├── envs/
│   ├── dev/           # Development environment
│   ├── prod/          # Production environment
│   └── argo/          # ArgoCD management cluster
├── modules/
│   ├── networking/    # VPC, subnets, NAT, firewall, PSA
│   ├── gke/           # GKE cluster + node pool (zonal or regional)
│   ├── waf/           # Cloud Armor security policies
│   ├── database/      # Cloud SQL PostgreSQL
│   ├── artifact-registry/
│   └── cloud-build/   # Cloud Build v2 triggers + GitHub connection
├── k8s/
│   ├── argocd/        # ArgoCD Helm values
│   └── argocd-clusters/  # Helm chart – registers dev/prod clusters in ArgoCD
└── scripts/
    ├── bootstrap.sh   # One-time GCS bucket + API setup
    ├── deploy.sh      # Plan & apply a component
    ├── destroy.sh     # Destroy a component or all
    ├── argocd-install.sh       # Install ArgoCD on argo cluster
    ├── argocd-add-clusters.sh  # Register dev/prod clusters in ArgoCD
    └── eso-install.sh          # Install External Secrets Operator on dev/prod
```

## Architecture

```
shared/                  envs/argo/          envs/dev/         envs/prod/
  Artifact Registry  ←── GKE nodes pull      GKE nodes pull    GKE nodes pull
  Cloud Build            ArgoCD cluster  ──→  Dev cluster       Prod cluster
  (GitHub → build →      (LoadBalancer IP)    WAF + SQL         WAF + SQL (HA)
   push image)           Workload Identity
                         (container.admin)
```

- **Shared layer** – deployed once; Artifact Registry + Cloud Build CI/CD
- **Argo layer** – ArgoCD management cluster; connects to dev/prod via Workload Identity
- **Env layers** – fully independent; each has its own state, VPC, GKE cluster, and database
- **Modules** – reusable; called from both shared and env roots

## CI/CD pipelines

### DEV pipeline (push to `main`)

1. Cloud Build trigger fires on push to `main` branch
2. Docker build with tags: `$SHORT_SHA` + `latest` (cache from `latest`)
3. Push both tags to dev Artifact Registry
4. ArgoCD Image Updater monitors the `latest` digest and syncs automatically

### PROD pipeline (push to `release/*`)

1. Cloud Build trigger fires on push to `release/X.Y.Z` branch
2. Extract version from branch name (e.g. `release/1.0.0` → `1.0.0`)
3. Build Docker image with version tag
4. Push to prod Artifact Registry
5. On-Demand vulnerability scan — blocks release if CRITICAL/HIGH found
6. Tag application repo: `{app}-{version}`
7. Update helm-charts repo:
   - Bump prod image tag in `{app}/values/prod.yaml`
   - Commit + tag helm-charts repo: `{app}-{version}`
8. ArgoCD syncs automatically when helm-charts is updated

## Environment specs

| Env  | Machine type  | Nodes (min/max) | DB                      | Notes               |
|------|---------------|-----------------|-------------------------|----------------------|
| prod | e2-standard-4 | 1 / 1           | db-g1-small REGIONAL HA | multi-zone ready (commented) |
| dev  | e2-standard-2 | 1 / 1           | db-g1-small ZONAL       | single-zone          |
| argo | e2-standard-4 | 1 / 1           | none                    | ArgoCD only          |

## Network layout

| Env  | Subnet        | Pods           | Services       | GKE Master     |
|------|---------------|----------------|----------------|----------------|
| argo | 10.0.0.0/20   | 10.48.0.0/18   | 10.20.0.0/18   | 172.16.0.0/28  |
| dev  | 10.1.0.0/20   | 10.49.0.0/18   | 10.21.0.0/18   | 172.16.1.0/28  |
| prod | 10.2.0.0/20   | 10.50.0.0/18   | 10.22.0.0/18   | 172.16.2.0/28  |

## Quick start

### 1. Bootstrap (one-time)

```bash
./scripts/bootstrap.sh <PROJECT_ID> <STATE_BUCKET_NAME>
```

### 2. Authenticate

```bash
gcloud auth application-default login
```

### 3. Deploy shared resources

```bash
# Fill in GitHub settings in shared/terraform.tfvars first
export TF_VAR_github_pat_token="ghp_..."
./scripts/deploy.sh shared
```

### 4. Deploy environments

```bash
./scripts/deploy.sh dev
./scripts/deploy.sh prod
./scripts/deploy.sh argo
```

### 5. Configure kubectl

```bash
gcloud container clusters get-credentials argo-global-cluster-0 \
  --zone europe-central2-a --project <PROJECT_ID>
```

### 6. Install ArgoCD

```bash
./scripts/argocd-install.sh
```

The script fetches the static IP and service account from Terraform outputs, installs ArgoCD via Helm, and prints the URL + admin password.

### 7. Register dev/prod clusters in ArgoCD

```bash
./scripts/argocd-add-clusters.sh
```

This deploys the `argocd-clusters` Helm chart which creates cluster secrets using Workload Identity authentication (`argocd-k8s-auth gcp`). After this step, dev and prod clusters appear in ArgoCD UI under Settings > Clusters.

### 8. Install External Secrets Operator

```bash
./scripts/eso-install.sh          # both dev + prod
./scripts/eso-install.sh dev      # dev only
./scripts/eso-install.sh prod     # prod only
```

Installs ESO via Helm on dev/prod clusters for syncing secrets from GCP Secret Manager into Kubernetes.

## ArgoCD access

ArgoCD is exposed via a LoadBalancer service with a Terraform-managed static regional IP.

```bash
# Get the URL
terraform -chdir=envs/argo output argocd_lb_ip

# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

### Cross-cluster authentication

ArgoCD authenticates to dev/prod clusters via GCP Workload Identity:

1. ArgoCD pods run as KSA `argocd-server` / `argocd-application-controller` / `argocd-repo-server`
2. These KSAs are bound to GCP SA `argo-argocd-sa` via Workload Identity
3. The GCP SA has `roles/container.admin` on the project
4. Cluster secrets use `argocd-k8s-auth gcp` exec provider (built into ArgoCD image)

No static tokens or kubeconfig files are stored.

## Cloud Build setup (manual step required)

Cloud Build connects to GitHub via the **Cloud Build GitHub App**. Before running `./scripts/deploy.sh shared`:

1. Go to **Cloud Build > Triggers > Connect Repository** in GCP Console
2. Select GitHub and authorize the Cloud Build GitHub App on your org/repo
3. Note the **Installation ID** from the URL (`/installations/<ID>`)
4. Set it in `shared/terraform.tfvars`:
   ```hcl
   github_app_installation_id = 12345678
   github_owner               = "your-org"
   ```

## Destroying infrastructure

```bash
# Single environment
./scripts/destroy.sh dev

# Everything (envs first, shared last)
./scripts/destroy.sh all
```

> **Note:** Cloud SQL must be destroyed before networking due to the Private Service Access (VPC peering) dependency. The destroy script handles this automatically.

## Security

- **Private GKE nodes** – nodes have no public IPs; egress via Cloud NAT
- **Workload Identity** – pods authenticate as GCP service accounts, no static keys
- **Network policies** – Calico CNI enabled on all clusters
- **Binary Authorization** – `PROJECT_SINGLETON_POLICY_ENFORCE` on all clusters
- **Shielded nodes** – secure boot + integrity monitoring
- **Cloud SQL** – private IP only, SSL enforced, no public access
- **Cloud Armor WAF** – OWASP CRS rules + rate limiting on dev/prod webapp ingress
- **Secrets** – DB passwords and GitHub PAT stored in Secret Manager
- **Vulnerability scanning** – On-Demand Scanning on prod images, blocks CRITICAL/HIGH
- **External Secrets Operator** – secrets synced from GCP Secret Manager, not stored in Git

## GCP APIs

Enabled automatically via Terraform:

| Layer  | APIs                                                                                     |
|--------|------------------------------------------------------------------------------------------|
| shared | artifactregistry, cloudbuild, iam, cloudresourcemanager, secretmanager, ondemandscanning |
| envs   | container, compute, servicenetworking, sqladmin, storage, iam, cloudresourcemanager, secretmanager |

## Cost estimates (europe-central2)

| Component               | dev/day  | prod/day | argo/day |
|-------------------------|----------|----------|----------|
| GKE nodes               | ~$1.80   | ~$3.60   | ~$3.60   |
| Cloud SQL               | ~$1.50   | ~$3.00   | –        |
| Networking/NAT          | ~$1.50   | ~$1.50   | ~$1.50   |
| Load Balancer           | ~$0.60   | ~$0.60   | ~$0.60   |
| **Total**               | **~$5.40** | **~$8.70** | **~$5.70** |

Shared layer (Artifact Registry + Cloud Build): ~$0.10/day
