# Core Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a multi-cloud Terraform monorepo with a GCP baseline module (budgets, IAM, APIs, logging, labels), GCS remote state, pre-commit hooks, and GitHub Actions CI/CD.

**Architecture:** A `bootstrap/` root creates the GCS state bucket with local state (run once). A reusable `providers/gcp/modules/baseline/` module configures any GCP project to a consistent baseline. Each project in `providers/gcp/projects/<name>/` is a thin wrapper that calls the module with its own GCS-backed state. GitHub Actions authenticates to GCP via Workload Identity Federation — no stored keys.

**Tech Stack:** Terraform >= 1.5, `hashicorp/google` ~> 5.0, `pre-commit`, `terraform-docs`, `antonbabenko/pre-commit-terraform`, GitHub Actions

---

## File Map

**Created:**
- `bootstrap/main.tf` — `google_storage_bucket` resource for TF state
- `bootstrap/variables.tf`
- `bootstrap/outputs.tf`
- `bootstrap/terraform.tfvars.example`
- `providers/gcp/modules/baseline/versions.tf` — required_providers
- `providers/gcp/modules/baseline/variables.tf` — all input variable declarations
- `providers/gcp/modules/baseline/outputs.tf` — service account email, WIF provider name
- `providers/gcp/modules/baseline/project.tf` — `google_project` resource (labels, billing)
- `providers/gcp/modules/baseline/apis.tf` — `google_project_service` for each enabled API
- `providers/gcp/modules/baseline/iam.tf` — admin user IAM binding
- `providers/gcp/modules/baseline/budgets.tf` — billing budget + email notification channel
- `providers/gcp/modules/baseline/logging.tf` — audit log config
- `providers/gcp/modules/baseline/workload_identity.tf` — WIF pool, provider, service account
- `providers/gcp/projects/my-project/main.tf` — provider + module call
- `providers/gcp/projects/my-project/variables.tf`
- `providers/gcp/projects/my-project/backend.tf` — GCS backend
- `providers/gcp/projects/my-project/terraform.tfvars.example`
- `.pre-commit-config.yaml`
- `.github/workflows/terraform.yml`

**Modified:**
- `CLAUDE.md` — add pre-commit setup instructions and import workflow note
- `README.md` — top-level usage overview
- `.gitignore` — confirm `*.tfvars` covered (already is)

---

## Task 1: Repo Scaffolding

**Files:**
- Create: `providers/gcp/modules/baseline/` (empty dir placeholder)
- Create: `providers/gcp/projects/my-project/` (empty dir placeholder)
- Create: `providers/aws/` (empty dir placeholder)
- Modify: `README.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p providers/gcp/modules/baseline
mkdir -p providers/gcp/projects/my-project
mkdir -p providers/aws
mkdir -p bootstrap
touch providers/aws/.gitkeep
```

- [ ] **Step 2: Update root README.md**

```markdown
# core-infra

Terraform monorepo managing personal cloud infrastructure across GCP, AWS, and others.

## Structure

- `bootstrap/` — Creates the GCS remote state bucket. Run once manually before anything else.
- `providers/gcp/modules/baseline/` — Reusable module: GCP project defaults (APIs, IAM, budgets, labels, logging, Workload Identity).
- `providers/gcp/projects/<name>/` — Per-project instantiation of the baseline module.
- `providers/aws/` — AWS infrastructure (future).
- `scripts/` — Helper scripts.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) — authenticated via `gcloud auth application-default login`
- [pre-commit](https://pre-commit.com/#install) — `pip install pre-commit && pre-commit install`
- [terraform-docs](https://terraform-docs.io/user-guide/installation/)

## First-time setup

1. `cd bootstrap && cp terraform.tfvars.example terraform.tfvars` — fill in values
2. `cd bootstrap && terraform init && terraform apply`
3. `cd providers/gcp/projects/my-project && cp terraform.tfvars.example terraform.tfvars` — fill in values
4. `terraform init && terraform plan`
5. Import existing resources (see CLAUDE.md)
```

- [ ] **Step 3: Update CLAUDE.md**

Add a new section after the existing content:

```markdown
## Pre-commit Hooks

Install once after cloning:
```bash
pip install pre-commit terraform-docs
pre-commit install
```

Hooks run automatically on `git commit`: `terraform fmt`, `terraform validate`, `terraform-docs` (regenerates README.md in each module/project dir).

## Importing Existing GCP Resources

When applying the GCP baseline against an existing project for the first time, import the project resource:

```bash
cd providers/gcp/projects/my-project
terraform import module.baseline.google_project.this projects/<PROJECT_ID>
```

If the billing account is already linked and IAM bindings exist, import them too — check `terraform plan` output and run `terraform import` for any resource showing unexpected diffs.

## Adding a New GCP Project

1. `cp -r providers/gcp/projects/my-project providers/gcp/projects/<new-name>`
2. Update `backend.tf` prefix to `gcp/<new-name>`
3. Fill in a new `terraform.tfvars`
4. `terraform init && terraform import module.baseline.google_project.this projects/<NEW_PROJECT_ID>`
5. `terraform plan && terraform apply`
```

- [ ] **Step 4: Commit**

```bash
git add providers/ bootstrap/ README.md CLAUDE.md
git commit -m "chore: scaffold repo directory structure"
```

---

## Task 2: Pre-commit Hooks

**Files:**
- Create: `.pre-commit-config.yaml`

- [ ] **Step 1: Create `.pre-commit-config.yaml`**

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.1
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
        args:
          - --tf-init-args=-upgrade
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
          - --hook-config=--create-file-if-not-exist=true
```

- [ ] **Step 2: Install and verify hooks**

```bash
pre-commit install
pre-commit run --all-files
```

Expected: passes (no .tf files yet) or reports "no files to check" for terraform hooks.

- [ ] **Step 3: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "chore: add pre-commit hooks for terraform fmt, validate, and docs"
```

---

## Task 3: Bootstrap — GCS State Bucket

**Files:**
- Create: `bootstrap/main.tf`
- Create: `bootstrap/variables.tf`
- Create: `bootstrap/outputs.tf`
- Create: `bootstrap/terraform.tfvars.example`

- [ ] **Step 1: Write `bootstrap/variables.tf`**

```hcl
variable "project_id" {
  type        = string
  description = "GCP project ID that will own the state bucket"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name for the GCS state bucket"
}

variable "region" {
  type        = string
  description = "GCS bucket location (e.g. US, EU, us-central1)"
  default     = "US"
}

variable "state_version_retention_days" {
  type        = number
  description = "Days to retain old state object versions before deletion"
  default     = 90
}
```

- [ ] **Step 2: Write `bootstrap/main.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

resource "google_storage_bucket" "tf_state" {
  name                        = var.bucket_name
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 5
      with_state         = "ARCHIVED"
      age                = var.state_version_retention_days
    }
  }
}
```

- [ ] **Step 3: Write `bootstrap/outputs.tf`**

```hcl
output "bucket_name" {
  description = "Name of the GCS state bucket"
  value       = google_storage_bucket.tf_state.name
}

output "bucket_url" {
  description = "gs:// URL of the state bucket"
  value       = google_storage_bucket.tf_state.url
}
```

- [ ] **Step 4: Write `bootstrap/terraform.tfvars.example`**

```hcl
project_id   = "your-gcp-project-id"
bucket_name  = "your-org-tf-state"   # must be globally unique
region       = "US"
```

- [ ] **Step 5: Validate**

```bash
cd bootstrap
terraform init
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Commit**

```bash
git add bootstrap/
git commit -m "feat: add bootstrap root module for GCS state bucket"
```

---

## Task 4: GCP Baseline Module — Versions & Variables

**Files:**
- Create: `providers/gcp/modules/baseline/versions.tf`
- Create: `providers/gcp/modules/baseline/variables.tf`
- Create: `providers/gcp/modules/baseline/outputs.tf`

- [ ] **Step 1: Write `providers/gcp/modules/baseline/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 2: Write `providers/gcp/modules/baseline/variables.tf`**

```hcl
variable "project_id" {
  type        = string
  description = "The GCP project ID to configure"
}

variable "project_name" {
  type        = string
  description = "Human-readable display name for the GCP project"
}

variable "billing_account" {
  type        = string
  description = "Billing account ID to associate with the project (format: XXXXXX-XXXXXX-XXXXXX)"
}

variable "admin_user" {
  type        = string
  description = "Google account email to bind as project owner (e.g. user@gmail.com)"
}

variable "region" {
  type        = string
  description = "Default GCP region"
  default     = "us-central1"
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD"
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds that trigger email alerts (e.g. [0.5, 0.9, 1.0])"
  default     = [0.5, 0.9, 1.0]

  validation {
    condition     = alltrue([for t in var.budget_thresholds : t > 0 && t <= 1.5])
    error_message = "Budget thresholds must be between 0 and 1.5."
  }
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the GCP project"
  default = {
    "managed-by" = "terraform"
  }
}

variable "enabled_apis" {
  type        = list(string)
  description = "GCP API services to enable on the project"
  default = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
}

variable "github_repo" {
  type        = string
  description = "GitHub repository for Workload Identity Federation in 'owner/repo' format. Set to null to skip WIF setup."
  default     = null
}
```

- [ ] **Step 3: Write `providers/gcp/modules/baseline/outputs.tf`**

```hcl
output "project_id" {
  description = "The GCP project ID"
  value       = google_project.this.project_id
}

output "project_number" {
  description = "The GCP project number"
  value       = google_project.this.number
}

output "github_actions_service_account_email" {
  description = "Email of the GitHub Actions service account (null if github_repo not set)"
  value       = try(google_service_account.github_actions[0].email, null)
}

output "workload_identity_provider" {
  description = "Full WIF provider resource name for use in GitHub Actions (null if github_repo not set)"
  value       = try(google_iam_workload_identity_pool_provider.github[0].name, null)
}
```

- [ ] **Step 4: Validate module structure**

```bash
cd providers/gcp/modules/baseline
terraform init
terraform validate
```

Expected: `Error: ... google_project.this` — no resource files yet. This confirms the interface is declared but not implemented.

- [ ] **Step 5: Commit**

```bash
git add providers/gcp/modules/baseline/versions.tf \
        providers/gcp/modules/baseline/variables.tf \
        providers/gcp/modules/baseline/outputs.tf
git commit -m "feat(gcp/baseline): define module interface (versions, variables, outputs)"
```

---

## Task 5: GCP Baseline Module — Project & Labels

**Files:**
- Create: `providers/gcp/modules/baseline/project.tf`

- [ ] **Step 1: Write `providers/gcp/modules/baseline/project.tf`**

```hcl
resource "google_project" "this" {
  project_id      = var.project_id
  name            = var.project_name
  billing_account = var.billing_account
  labels          = var.labels

  lifecycle {
    # Prevent accidental project deletion
    prevent_destroy = true
    # Allow labels to be updated without replacing
    ignore_changes = [labels]
  }
}
```

Note: `ignore_changes = [labels]` is intentional — terraform-docs will flag this. Labels are applied but drift from console edits won't trigger replacement. Remove if you want strict label enforcement.

- [ ] **Step 2: Validate**

```bash
cd providers/gcp/modules/baseline
terraform validate
```

Expected: errors about missing `google_service_account.github_actions` referenced in `outputs.tf` — that's fine, remaining files will resolve them.

- [ ] **Step 3: Commit**

```bash
git add providers/gcp/modules/baseline/project.tf
git commit -m "feat(gcp/baseline): add project resource with labels and billing account"
```

---

## Task 6: GCP Baseline Module — APIs

**Files:**
- Create: `providers/gcp/modules/baseline/apis.tf`

- [ ] **Step 1: Write `providers/gcp/modules/baseline/apis.tf`**

```hcl
resource "google_project_service" "apis" {
  for_each = toset(var.enabled_apis)

  project = google_project.this.project_id
  service = each.value

  # Don't disable APIs on destroy — other resources may depend on them
  disable_on_destroy         = false
  disable_dependent_services = false
}
```

- [ ] **Step 2: Validate**

```bash
cd providers/gcp/modules/baseline
terraform validate
```

Expected: still errors about missing `google_service_account.github_actions` from outputs.tf — acceptable at this stage.

- [ ] **Step 3: Commit**

```bash
git add providers/gcp/modules/baseline/apis.tf
git commit -m "feat(gcp/baseline): enable configurable GCP APIs"
```

---

## Task 7: GCP Baseline Module — IAM

**Files:**
- Create: `providers/gcp/modules/baseline/iam.tf`

- [ ] **Step 1: Write `providers/gcp/modules/baseline/iam.tf`**

```hcl
# Bind the personal admin account as project owner
resource "google_project_iam_member" "admin" {
  project = google_project.this.project_id
  role    = "roles/owner"
  member  = "user:${var.admin_user}"

  depends_on = [google_project_service.apis]
}
```

- [ ] **Step 2: Validate**

```bash
cd providers/gcp/modules/baseline
terraform validate
```

Expected: still errors about `google_service_account.github_actions` — acceptable, Task 9 resolves this.

- [ ] **Step 3: Commit**

```bash
git add providers/gcp/modules/baseline/iam.tf
git commit -m "feat(gcp/baseline): add admin IAM binding for personal account"
```

---

## Task 8: GCP Baseline Module — Budget Alerts

**Files:**
- Create: `providers/gcp/modules/baseline/budgets.tf`

- [ ] **Step 1: Write `providers/gcp/modules/baseline/budgets.tf`**

```hcl
resource "google_monitoring_notification_channel" "budget_email" {
  project      = google_project.this.project_id
  display_name = "Budget Alert — ${var.project_id}"
  type         = "email"

  labels = {
    email_address = var.admin_user
  }

  depends_on = [google_project_service.apis]
}

resource "google_billing_budget" "project" {
  billing_account = var.billing_account
  display_name    = "${var.project_id}-monthly-budget"

  budget_filter {
    projects = ["projects/${google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(floor(var.budget_amount))
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.budget_email.id
    ]
    disable_default_iam_recipients = true
  }
}
```

- [ ] **Step 2: Validate**

```bash
cd providers/gcp/modules/baseline
terraform validate
```

Expected: still errors about `google_service_account.github_actions` — acceptable.

- [ ] **Step 3: Commit**

```bash
git add providers/gcp/modules/baseline/budgets.tf
git commit -m "feat(gcp/baseline): add billing budget with configurable thresholds and email alerts"
```

---

## Task 9: GCP Baseline Module — Logging

**Files:**
- Create: `providers/gcp/modules/baseline/logging.tf`

- [ ] **Step 1: Write `providers/gcp/modules/baseline/logging.tf`**

```hcl
# Enable Data Access audit logs for all services
resource "google_project_iam_audit_config" "default" {
  project = google_project.this.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }

  depends_on = [google_project_service.apis]
}
```

- [ ] **Step 2: Validate**

```bash
cd providers/gcp/modules/baseline
terraform validate
```

Expected: still errors about `google_service_account.github_actions` — acceptable, resolved in next task.

- [ ] **Step 3: Commit**

```bash
git add providers/gcp/modules/baseline/logging.tf
git commit -m "feat(gcp/baseline): enable audit logging for admin and data access"
```

---

## Task 10: GCP Baseline Module — Workload Identity

**Files:**
- Create: `providers/gcp/modules/baseline/workload_identity.tf`

- [ ] **Step 1: Write `providers/gcp/modules/baseline/workload_identity.tf`**

```hcl
# All resources in this file are conditional on var.github_repo being set

resource "google_service_account" "github_actions" {
  count = var.github_repo != null ? 1 : 0

  project      = google_project.this.project_id
  account_id   = "github-actions"
  display_name = "GitHub Actions"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation"

  depends_on = [google_project_service.apis]
}

# Grant the SA permissions needed to run terraform plan/apply
resource "google_project_iam_member" "github_actions_roles" {
  for_each = var.github_repo != null ? toset([
    "roles/viewer",
    "roles/iam.securityAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/billing.projectManager",
    "roles/monitoring.editor",
    "roles/logging.admin",
  ]) : toset([])

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

resource "google_iam_workload_identity_pool" "github" {
  count = var.github_repo != null ? 1 : 0

  project                   = google_project.this.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions OIDC tokens"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.github_repo != null ? 1 : 0

  project                            = google_project.this.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions OIDC Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Only tokens from this specific repo are accepted
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_wif" {
  count = var.github_repo != null ? 1 : 0

  service_account_id = google_service_account.github_actions[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.repository/${var.github_repo}"
}
```

- [ ] **Step 2: Validate the complete module**

```bash
cd providers/gcp/modules/baseline
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add providers/gcp/modules/baseline/workload_identity.tf
git commit -m "feat(gcp/baseline): add Workload Identity Federation for GitHub Actions"
```

---

## Task 11: GCP Project Instantiation

**Files:**
- Create: `providers/gcp/projects/my-project/main.tf`
- Create: `providers/gcp/projects/my-project/variables.tf`
- Create: `providers/gcp/projects/my-project/backend.tf`
- Create: `providers/gcp/projects/my-project/terraform.tfvars.example`

- [ ] **Step 1: Write `providers/gcp/projects/my-project/variables.tf`**

```hcl
variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "project_name" {
  type        = string
  description = "Human-readable display name for the GCP project"
}

variable "billing_account" {
  type        = string
  description = "Billing account ID (format: XXXXXX-XXXXXX-XXXXXX)"
}

variable "admin_user" {
  type        = string
  description = "Google account email to bind as project owner"
}

variable "region" {
  type        = string
  description = "Default GCP region"
  default     = "us-central1"
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD"
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds for budget alerts"
  default     = [0.5, 0.9, 1.0]
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the project"
  default = {
    env          = "personal"
    "managed-by" = "terraform"
  }
}

variable "enabled_apis" {
  type        = list(string)
  description = "GCP APIs to enable"
  default = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
}

variable "github_repo" {
  type        = string
  description = "GitHub repo for WIF in 'owner/repo' format. Null skips WIF setup."
  default     = null
}
```

- [ ] **Step 2: Write `providers/gcp/projects/my-project/backend.tf`**

Replace `your-tf-state-bucket` with the actual bucket name output from bootstrap.

```hcl
terraform {
  backend "gcs" {
    bucket = "your-tf-state-bucket"
    prefix = "gcp/my-project"
  }
}
```

- [ ] **Step 3: Write `providers/gcp/projects/my-project/main.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "baseline" {
  source = "../../modules/baseline"

  project_id        = var.project_id
  project_name      = var.project_name
  billing_account   = var.billing_account
  admin_user        = var.admin_user
  region            = var.region
  budget_amount     = var.budget_amount
  budget_thresholds = var.budget_thresholds
  labels            = var.labels
  enabled_apis      = var.enabled_apis
  github_repo       = var.github_repo
}
```

- [ ] **Step 4: Write `providers/gcp/projects/my-project/terraform.tfvars.example`**

```hcl
project_id      = "your-gcp-project-id"
project_name    = "My GCP Project"
billing_account = "XXXXXX-XXXXXX-XXXXXX"
admin_user      = "you@gmail.com"
region          = "us-central1"
budget_amount   = 20
budget_thresholds = [0.5, 0.9, 1.0]
github_repo     = "your-github-username/core-infra"

labels = {
  env          = "personal"
  owner        = "your-name"
  "managed-by" = "terraform"
}

enabled_apis = [
  "compute.googleapis.com",
  "iam.googleapis.com",
  "cloudbilling.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "logging.googleapis.com",
  "monitoring.googleapis.com",
  "iamcredentials.googleapis.com",
]
```

- [ ] **Step 5: Validate**

```bash
cd providers/gcp/projects/my-project
terraform init
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Commit**

```bash
git add providers/gcp/projects/my-project/
git commit -m "feat(gcp/projects): add my-project instantiation of baseline module"
```

---

## Task 12: GitHub Actions Workflow

**Files:**
- Create: `.github/workflows/terraform.yml`

- [ ] **Step 1: Create `.github/workflows/` directory**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Write `.github/workflows/terraform.yml`**

```yaml
name: Terraform

on:
  pull_request:
    branches: [main]
    paths:
      - 'providers/**'
      - 'bootstrap/**'
  push:
    branches: [main]
    paths:
      - 'providers/**'

jobs:
  terraform:
    name: Terraform / ${{ matrix.project }}
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write       # Required for WIF token exchange
      pull-requests: write  # Required to post plan comments

    strategy:
      fail-fast: false
      matrix:
        project:
          - providers/gcp/projects/my-project

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.5"

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Terraform Init
        working-directory: ${{ matrix.project }}
        run: terraform init -reconfigure

      - name: Terraform Format Check
        working-directory: ${{ matrix.project }}
        run: terraform fmt -check -recursive

      - name: Terraform Validate
        working-directory: ${{ matrix.project }}
        run: terraform validate

      - name: Terraform Plan
        id: plan
        if: github.event_name == 'pull_request'
        working-directory: ${{ matrix.project }}
        run: |
          terraform plan -no-color -input=false 2>&1 | tee plan_output.txt
          echo "plan_output<<EOF" >> $GITHUB_OUTPUT
          cat plan_output.txt >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
        continue-on-error: true

      - name: Post Plan Comment
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const project = '${{ matrix.project }}';
            const planOutput = `${{ steps.plan.outputs.plan_output }}`;
            const planStatus = '${{ steps.plan.outcome }}' === 'success' ? '✅' : '❌';
            const body = [
              `### ${planStatus} Terraform Plan: \`${project}\``,
              '',
              '<details><summary>Show Plan</summary>',
              '',
              '```terraform',
              planOutput,
              '```',
              '',
              '</details>'
            ].join('\n');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body
            });

      - name: Terraform Apply
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        working-directory: ${{ matrix.project }}
        run: terraform apply -auto-approve -input=false
```

- [ ] **Step 3: Add GitHub secrets documentation to CLAUDE.md**

Append to CLAUDE.md:

```markdown
## GitHub Actions Secrets

Two repository secrets must be set in GitHub (Settings → Secrets and variables → Actions):

- `GCP_WORKLOAD_IDENTITY_PROVIDER` — full WIF provider resource name, output from `terraform output workload_identity_provider` in the project dir
- `GCP_SERVICE_ACCOUNT` — service account email, output from `terraform output github_actions_service_account_email`

These are populated after the first `terraform apply` of the GCP baseline.
```

- [ ] **Step 4: Validate workflow YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/terraform.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 5: Commit**

```bash
git add .github/ CLAUDE.md
git commit -m "feat: add GitHub Actions workflow for terraform plan and apply"
```

---

## Task 13: Apply Bootstrap & First Plan

This task is run manually after completing all code tasks.

- [ ] **Step 1: Create bootstrap tfvars**

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values: project_id, bucket_name, region
```

- [ ] **Step 2: Apply bootstrap**

```bash
terraform init
terraform plan   # verify: 1 resource to add (google_storage_bucket)
terraform apply
```

Expected output includes:
```
bucket_name = "your-tf-state-bucket"
bucket_url  = "gs://your-tf-state-bucket"
```

- [ ] **Step 3: Update my-project backend.tf with real bucket name**

In `providers/gcp/projects/my-project/backend.tf`, replace `your-tf-state-bucket` with the actual bucket name from step 2 output.

- [ ] **Step 4: Create my-project tfvars**

```bash
cd providers/gcp/projects/my-project
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values
```

- [ ] **Step 5: Init and import existing project**

```bash
terraform init
terraform import module.baseline.google_project.this projects/<YOUR_PROJECT_ID>
```

Expected: `Import successful!`

- [ ] **Step 6: Plan and review**

```bash
terraform plan
```

Review output carefully. If the plan shows unexpected diffs for existing resources (IAM bindings, APIs already enabled), import them:

```bash
# Example: import an existing IAM member binding
terraform import 'module.baseline.google_project_iam_member.admin' \
  "your-project-id roles/owner user:you@gmail.com"
```

- [ ] **Step 7: Apply**

```bash
terraform apply
```

- [ ] **Step 8: Note WIF outputs and set GitHub secrets**

```bash
terraform output github_actions_service_account_email
terraform output workload_identity_provider
```

Set both values as GitHub repository secrets (`GCP_SERVICE_ACCOUNT` and `GCP_WORKLOAD_IDENTITY_PROVIDER`).

- [ ] **Step 9: Commit backend.tf update**

```bash
git add providers/gcp/projects/my-project/backend.tf
git commit -m "chore(gcp/my-project): set GCS backend bucket name"
```
