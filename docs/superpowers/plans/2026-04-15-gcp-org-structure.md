# GCP Organization Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce GCP organization-level folder hierarchy (`personal/`, `certs/`) under `tapshalkar.com`, move `adits-gcp` under the `personal/` folder, and wire folder IDs into the baseline module via `terraform_remote_state`.

**Architecture:** A new `providers/gcp/org/` root manages folders and org IAM. The baseline module gains an optional `folder_id` variable. The `adits-gcp` project root moves from `providers/gcp/projects/adits-gcp/` to `providers/gcp/projects/personal/adits-gcp/` with its GCS state prefix migrated to match. The org root's outputs are consumed via `terraform_remote_state`.

**Tech Stack:** Terraform >= 1.5, `hashicorp/google ~> 5.0`, GCS remote state backend (`adits-gcp-core-infra-tfstate`).

---

## File Map

| Action | File |
|--------|------|
| Create | `providers/gcp/org/versions.tf` |
| Create | `providers/gcp/org/backend.tf` |
| Create | `providers/gcp/org/variables.tf` |
| Create | `providers/gcp/org/main.tf` |
| Create | `providers/gcp/org/outputs.tf` |
| Create | `providers/gcp/org/terraform.tfvars.example` |
| Modify | `providers/gcp/modules/baseline/variables.tf` |
| Modify | `providers/gcp/modules/baseline/project.tf` |
| Move   | `providers/gcp/projects/adits-gcp/` → `providers/gcp/projects/personal/adits-gcp/` |
| Modify | `providers/gcp/projects/personal/adits-gcp/backend.tf` |
| Modify | `providers/gcp/projects/personal/adits-gcp/main.tf` |
| Create | `providers/gcp/projects/certs/.gitkeep` |
| Modify | `CLAUDE.md` |

---

### Task 1: Add `folder_id` to baseline module

**Files:**
- Modify: `providers/gcp/modules/baseline/variables.tf`
- Modify: `providers/gcp/modules/baseline/project.tf`

- [ ] **Step 1: Add `folder_id` variable to baseline**

Append to `providers/gcp/modules/baseline/variables.tf`:

```hcl
variable "folder_id" {
  type        = string
  description = "GCP folder to place this project under (e.g. folders/1234567890). Null places the project directly under the organization."
  default     = null
}
```

- [ ] **Step 2: Set `folder_id` on `google_project.this`**

Edit `providers/gcp/modules/baseline/project.tf`. Replace:

```hcl
resource "google_project" "this" {
  project_id      = var.project_id
  name            = var.project_name
  billing_account = var.billing_account
  labels          = var.labels

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels]
  }
}
```

With:

```hcl
resource "google_project" "this" {
  project_id      = var.project_id
  name            = var.project_name
  billing_account = var.billing_account
  folder_id       = var.folder_id
  labels          = var.labels

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels]
  }
}
```

- [ ] **Step 3: Validate the module**

```bash
cd providers/gcp/modules/baseline
terraform init -backend=false 2>&1 | tail -2
```

Expected output: `Terraform has been successfully initialized!`

- [ ] **Step 4: Commit**

```bash
git add providers/gcp/modules/baseline/variables.tf providers/gcp/modules/baseline/project.tf
git commit -m "feat(baseline): add optional folder_id variable to google_project"
```

---

### Task 2: Create `providers/gcp/org/` root

**Files:**
- Create: `providers/gcp/org/versions.tf`
- Create: `providers/gcp/org/backend.tf`
- Create: `providers/gcp/org/variables.tf`
- Create: `providers/gcp/org/main.tf`
- Create: `providers/gcp/org/outputs.tf`
- Create: `providers/gcp/org/terraform.tfvars.example`

- [ ] **Step 1: Create `versions.tf`**

```hcl
# providers/gcp/org/versions.tf
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {}
```

- [ ] **Step 2: Create `backend.tf`**

```hcl
# providers/gcp/org/backend.tf
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "gcp/org"
  }
}
```

- [ ] **Step 3: Create `variables.tf`**

```hcl
# providers/gcp/org/variables.tf
variable "domain" {
  type        = string
  description = "Google Workspace domain used to look up the GCP organization (e.g. tapshalkar.com)."
}

variable "admin_user" {
  type        = string
  description = "Google Workspace email to bind as Organization Admin (e.g. aditya@tapshalkar.com)."

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.admin_user))
    error_message = "admin_user must be a valid email address."
  }
}
```

- [ ] **Step 4: Create `main.tf`**

```hcl
# providers/gcp/org/main.tf
data "google_organization" "this" {
  domain = var.domain
}

resource "google_folder" "personal" {
  display_name = "personal"
  parent       = data.google_organization.this.name
}

resource "google_folder" "certs" {
  display_name = "certs"
  parent       = data.google_organization.this.name
}

resource "google_organization_iam_member" "admin" {
  org_id = data.google_organization.this.org_id
  role   = "roles/resourcemanager.organizationAdmin"
  member = "user:${var.admin_user}"
}
```

- [ ] **Step 5: Create `outputs.tf`**

```hcl
# providers/gcp/org/outputs.tf
output "org_id" {
  description = "GCP organization ID"
  value       = data.google_organization.this.org_id
}

output "personal_folder_id" {
  description = "Resource name of the personal/ folder (format: folders/<ID>)"
  value       = google_folder.personal.name
}

output "certs_folder_id" {
  description = "Resource name of the certs/ folder (format: folders/<ID>)"
  value       = google_folder.certs.name
}
```

- [ ] **Step 6: Create `terraform.tfvars.example`**

```hcl
# providers/gcp/org/terraform.tfvars.example
domain     = "tapshalkar.com"
admin_user = "aditya@tapshalkar.com"
```

- [ ] **Step 7: Validate**

```bash
cd providers/gcp/org
terraform init -backend=false 2>&1 | tail -2
terraform validate
```

Expected:
```
Terraform has been successfully initialized!
Success! The configuration is valid.
```

- [ ] **Step 8: Commit**

```bash
git add providers/gcp/org/
git commit -m "feat(gcp/org): add org root with personal and certs folders"
```

---

### Task 3: Migrate state prefix and restructure projects directory

**Files:**
- Move: `providers/gcp/projects/adits-gcp/` → `providers/gcp/projects/personal/adits-gcp/`
- Modify: `providers/gcp/projects/personal/adits-gcp/backend.tf`
- Create: `providers/gcp/projects/certs/.gitkeep`

- [ ] **Step 1: Copy GCS state to new prefix**

```bash
gsutil cp \
  gs://adits-gcp-core-infra-tfstate/gcp/adits-gcp/default.tfstate \
  gs://adits-gcp-core-infra-tfstate/gcp/projects/personal/adits-gcp/default.tfstate
```

Expected: `Copying gs://adits-gcp-core-infra-tfstate/gcp/adits-gcp/default.tfstate`

- [ ] **Step 2: Verify the new state file exists**

```bash
gsutil ls gs://adits-gcp-core-infra-tfstate/gcp/projects/personal/adits-gcp/
```

Expected: `gs://adits-gcp-core-infra-tfstate/gcp/projects/personal/adits-gcp/default.tfstate`

- [ ] **Step 3: Move the project directory with git**

```bash
mkdir -p providers/gcp/projects/personal
git mv providers/gcp/projects/adits-gcp providers/gcp/projects/personal/adits-gcp
```

- [ ] **Step 4: Create `certs/` placeholder**

```bash
mkdir -p providers/gcp/projects/certs
touch providers/gcp/projects/certs/.gitkeep
```

- [ ] **Step 5: Update `backend.tf` to new prefix**

Replace the entire contents of `providers/gcp/projects/personal/adits-gcp/backend.tf` with:

```hcl
terraform {
  backend "gcs" {
    bucket = "adits-gcp-core-infra-tfstate"
    prefix = "gcp/projects/personal/adits-gcp"
  }
}
```

- [ ] **Step 6: Re-initialize against new state prefix**

```bash
cd providers/gcp/projects/personal/adits-gcp
terraform init -reconfigure
```

Expected: `Terraform has been successfully initialized!`

- [ ] **Step 7: Verify zero changes**

```bash
terraform plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

If you see unexpected changes, stop and investigate before continuing. Do not apply.

- [ ] **Step 8: Commit**

```bash
cd ../../../..  # back to repo root
git add providers/gcp/projects/personal/adits-gcp/backend.tf providers/gcp/projects/certs/.gitkeep
git commit -m "chore(gcp): move adits-gcp under projects/personal/, migrate state prefix"
```

---

### Task 4: Wire org remote state into adits-gcp

**Files:**
- Modify: `providers/gcp/projects/personal/adits-gcp/main.tf`

- [ ] **Step 1: Update `main.tf` to add org remote state and pass `folder_id`**

Replace the entire contents of `providers/gcp/projects/personal/adits-gcp/main.tf` with:

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
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}

data "terraform_remote_state" "pagerduty" {
  backend = "gcs"
  config = {
    bucket = "adits-gcp-core-infra-tfstate"
    prefix = "pagerduty"
  }
}

data "terraform_remote_state" "gcp_org" {
  backend = "gcs"
  config = {
    bucket = "adits-gcp-core-infra-tfstate"
    prefix = "gcp/org"
  }
}

module "baseline" {
  source = "../../../modules/baseline"

  project_id                    = var.project_id
  project_name                  = var.project_name
  billing_account               = var.billing_account
  admin_user                    = var.admin_user
  region                        = var.region
  budget_amount                 = var.budget_amount
  budget_thresholds             = var.budget_thresholds
  labels                        = var.labels
  enabled_apis                  = var.enabled_apis
  github_repo                   = var.github_repo
  enable_data_access_audit_logs = var.enable_data_access_audit_logs
  pagerduty_integration_key     = data.terraform_remote_state.pagerduty.outputs.integration_key
  folder_id                     = data.terraform_remote_state.gcp_org.outputs.personal_folder_id
}
```

Note: `source` is now `../../../modules/baseline` (three levels up) instead of `../../modules/baseline`.

- [ ] **Step 2: Validate**

```bash
cd providers/gcp/projects/personal/adits-gcp
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add providers/gcp/projects/personal/adits-gcp/main.tf
git commit -m "feat(adits-gcp): wire gcp/org remote state, pass folder_id to baseline"
```

---

### Task 5: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the Structure section**

In `CLAUDE.md`, replace the `## Structure` section content with:

```markdown
## Structure

- `bootstrap/` — creates the GCS remote state bucket (run once, local state).
- `providers/gcp/org/` — GCP organization root: `personal/` and `certs/` folders + org IAM. Apply before projects.
- `providers/gcp/modules/baseline/` — reusable module configuring GCP project defaults.
- `providers/gcp/projects/<folder>/<name>/` — per-project instantiation of the baseline module, grouped by folder (`personal/`, `certs/`).
- `providers/pagerduty/` — PagerDuty service + integration. Apply before GCP projects.
- `providers/aws/` — AWS infrastructure (future, same pattern).
- `scripts/` — helper scripts for import, init, etc.
```

- [ ] **Step 2: Update the Adding a New GCP Project section**

In `CLAUDE.md`, replace the `## Adding a New GCP Project` section with:

```markdown
## Adding a New GCP Project

1. `cp -r providers/gcp/projects/personal/adits-gcp providers/gcp/projects/<folder>/<new-name>`
2. Update `backend.tf` prefix to `gcp/projects/<folder>/<new-name>`
3. Fill in a new `terraform.tfvars`
4. `terraform init -backend-config="bucket=adits-gcp-core-infra-tfstate"`
5. `terraform import module.baseline.google_project.this projects/<NEW_PROJECT_ID>`
6. `terraform plan && terraform apply`
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for gcp/org folder structure"
```

---

### Task 6: Apply org root and move project under folder

> This task involves real infrastructure changes. Run from `providers/gcp/org/`.

- [ ] **Step 1: Create `terraform.tfvars`**

```bash
cp providers/gcp/org/terraform.tfvars.example providers/gcp/org/terraform.tfvars
# Fill in: domain = "tapshalkar.com", admin_user = "aditya@tapshalkar.com"
```

- [ ] **Step 2: Check whether the `personal/` folder already exists in GCP console**

Open GCP Console → Resource Manager. If a folder named `personal` already exists, note its numeric ID and run:

```bash
cd providers/gcp/org
terraform init -backend-config="bucket=adits-gcp-core-infra-tfstate"
terraform import google_folder.personal folders/<FOLDER_ID>
```

If no folder exists, skip the import and proceed directly to apply.

- [ ] **Step 3: Check whether the org IAM binding already exists**

If `aditya@tapshalkar.com` is already bound as `roles/resourcemanager.organizationAdmin` in the GCP console, import it:

```bash
# Get ORG_ID from: gcloud organizations list
terraform import \
  google_organization_iam_member.admin \
  "organizations/<ORG_ID> roles/resourcemanager.organizationAdmin user:aditya@tapshalkar.com"
```

If not, skip the import.

- [ ] **Step 4: Apply the org root**

```bash
cd providers/gcp/org
terraform plan
terraform apply
```

Expected resources created/imported: `google_folder.personal`, `google_folder.certs`, `google_organization_iam_member.admin`.

- [ ] **Step 5: Apply adits-gcp to move project under personal/ folder**

```bash
cd providers/gcp/projects/personal/adits-gcp
terraform plan
```

Expected: one in-place update — `google_project.this` `folder_id` changes from `null` to `folders/<ID>`. No destroy.

```bash
terraform apply
```

- [ ] **Step 6: Verify in GCP console**

Open GCP Console → Resource Manager. Confirm `adits-gcp` appears under the `personal/` folder.
