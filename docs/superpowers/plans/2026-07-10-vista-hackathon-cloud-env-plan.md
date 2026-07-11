# Vista Hackathon 2026 Cloud Environment — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provision one GCP project and one AWS account, both named `vista-hackathon-2026` under the `personal/` folder/OU, as plain instantiations of the existing shared baseline modules, ready for agentic-AI development ahead of the July 13–15 hackathon.

**Architecture:** Both new roots follow this repo's established "baseline module + per-project root" pattern (`providers/gcp/projects/personal/vista-hackathon-2026/` and `providers/aws/accounts/personal/vista-hackathon-2026/`), each calling a shared, unmodified `modules/baseline` module. Neither shared module is changed. The GCP project is created directly by Terraform (`google_project` resource — no manual `gcloud` step needed). The AWS account is likewise created directly by Terraform (`aws_organizations_account` resource) — this repo's `create-aws-account.sh` script generates an older pattern requiring manual `aws organizations create-account`, but the actually-deployed `tapshalkar-com-sandbox` account uses the newer, fully-Terraform-managed pattern; this plan follows the newer pattern and treats the script's boilerplate as a starting point only.

**Tech Stack:** Terraform >= 1.5, `hashicorp/google` ~> 5.0, `hashicorp/aws` ~> 5.0, GCS remote state backend (`tapshalkar-com-tfstate`).

## Global Constraints

- Region: `us-east1` (GCP) / `us-east-1` (AWS) — matches every other `personal/` project/account in this repo.
- Budget: `budget_amount = 100`, `budget_thresholds = [0.5, 0.9, 1.0]` on both providers.
- `notification_email` (AWS) is left unset in tfvars — it coalesces from the management account's `notification_email`, matching the `tapshalkar-com-sandbox` pattern.
- No changes to `providers/gcp/modules/baseline` or `providers/aws/modules/baseline` — both new roots are plain instantiations.
- Teammate IAM access is out of scope for this plan (handled by a separate, not-yet-created hackathon repo — see spec's Non-Goals).
- Any step that runs `terraform apply` (creates real, billable cloud resources) requires your explicit go-ahead at that step — it will not run automatically even under batch execution.

---

## Prerequisite (blocking Task 2 and Task 4)

Your AWS CLI session is currently expired (`aws sts get-caller-identity` fails with "Your session has expired"). Before Task 2's `terraform plan` or Task 4's `terraform apply` can run, you need to re-authenticate — most likely via:

```bash
aws sso login
```

(Your AWS Organization has IAM Identity Center configured — `providers/aws/org/outputs.tf` exposes `sso_instance_arn` — so `aws sso login` is the most likely command. If your setup differs, use whatever command you normally use, then confirm with `aws sts get-caller-identity`.)

GCP is already authenticated as `aditya@tapshalkar.com` (confirmed via `gcloud auth list`) — no action needed there.

---

### Task 1: Scaffold and configure the GCP project

**Files:**
- Create (via script): `providers/gcp/projects/personal/vista-hackathon-2026/{backend.hcl,backend.tf,main.tf,outputs.tf,variables.tf,terraform.tfvars,terraform.tfvars.example,README.md}`
- Modify (via script): `Makefile`, `scripts/tf-all.sh`

**Interfaces:**
- Produces: a `terraform plan` showing Terraform will create `module.baseline.google_project.this` (project ID `vista-hackathon-2026`) plus its APIs, budget, and workload identity resources. Later tasks (3, 5) apply this plan and consume its outputs (`workload_identity_provider`, `github_actions_service_account_email`).

- [ ] **Step 1: Run the scaffolding script**

```bash
cd /Users/adityatapshalkar/Documents/Dev/Repos/core-infra
./scripts/create-gcp-project.sh personal vista-hackathon-2026
```

Expected: prints `✓ Project scaffolded at: providers/gcp/projects/personal/vista-hackathon-2026/` and confirms it patched the Makefile and `ci-plan` target.

- [ ] **Step 2: Replace the generated `terraform.tfvars` with hackathon-specific values**

Open `providers/gcp/projects/personal/vista-hackathon-2026/terraform.tfvars` and replace its contents with:

```hcl
project_id        = "vista-hackathon-2026"
project_name      = "Vista Hackathon 2026"
admin_user        = "aditya@tapshalkar.com"
region            = "us-east1"
budget_amount     = 100
budget_thresholds = [0.5, 0.9, 1.0]

labels = {
  env          = "personal"
  owner        = "aditya-tapshalkar"
  "managed-by" = "terraform"
}

enabled_apis = [
  "compute.googleapis.com",
  "iam.googleapis.com",
  "cloudbilling.googleapis.com",
  "billingbudgets.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "logging.googleapis.com",
  "monitoring.googleapis.com",
  "iamcredentials.googleapis.com",
  "aiplatform.googleapis.com",
  "discoveryengine.googleapis.com",
  "run.googleapis.com",
  "artifactregistry.googleapis.com",
  "secretmanager.googleapis.com",
  "storage.googleapis.com",
]
```

- [ ] **Step 3: Format and validate**

```bash
cd providers/gcp/projects/personal/vista-hackathon-2026
terraform fmt -recursive
terraform init -backend-config=backend.hcl
terraform validate
```

Expected: `terraform validate` prints `Success! The configuration is valid.`

- [ ] **Step 4: Dry-run plan (read-only, no resources created)**

```bash
terraform plan
```

Expected: plan shows resources to be **created** (not changed/destroyed) — `module.baseline.google_project.this`, 14 `google_project_service.apis["..."]` resources, budget resources, and workload identity resources. No errors. Do not apply yet — that's Task 3.

- [ ] **Step 5: Commit**

```bash
cd /Users/adityatapshalkar/Documents/Dev/Repos/core-infra
git add providers/gcp/projects/personal/vista-hackathon-2026 Makefile scripts/tf-all.sh
git commit -m "$(cat <<'EOF'
feat(gcp/vista-hackathon-2026): scaffold new personal project for hackathon

Ready to apply — enables Vertex AI/Agent Builder APIs alongside the
standard baseline set, $100/mo budget with tiered alerts.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Scaffold and configure the AWS account (Terraform-managed creation)

**Files:**
- Create (via script, then rewritten): `providers/aws/accounts/personal/vista-hackathon-2026/{backend.hcl,versions.tf,main.tf,outputs.tf,variables.tf,terraform.tfvars.example,README.md}`
- Modify (via script): `providers/github/main.tf`, `Makefile`, `scripts/tf-all.sh`

**Interfaces:**
- Consumes: `data.terraform_remote_state.org.outputs.personal_ou_id` (from `providers/aws/org`), `data.terraform_remote_state.management.outputs.notification_email` (from `providers/aws/accounts/management/tapshalkar-com`), `data.terraform_remote_state.github.outputs.core_infra_repo_full_name`, `data.terraform_remote_state.pagerduty.outputs.aws_integration_key`.
- Produces: `module.baseline.account_id`, `module.baseline.github_actions_role_arn` — consumed by Task 4 (apply) and Task 5 (`providers/github` secret publishing).

- [ ] **Step 1: Run the scaffolding script**

```bash
cd /Users/adityatapshalkar/Documents/Dev/Repos/core-infra
./scripts/create-aws-account.sh personal vista-hackathon-2026
```

Expected: prints `✓ 'vista-hackathon-2026' scaffolded.` and lists the files it changed (new account dir, `providers/github/main.tf`, `Makefile`, `scripts/tf-all.sh`).

- [ ] **Step 2: Overwrite `versions.tf` to match the account-creation pattern used by `tapshalkar-com-sandbox`**

The script generates a `versions.tf` that assumes the AWS account already exists (single `assume_role` provider). Replace `providers/aws/accounts/personal/vista-hackathon-2026/versions.tf` with:

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/personal/vista-hackathon-2026"
  }
}

provider "aws" {
  region = var.region
  # Uses management account credentials to create the org member account
}

provider "aws" {
  alias  = "account"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.this.id}:role/OrganizationAccountAccessRole"
  }
}
```

- [ ] **Step 3: Overwrite `main.tf` to create the account directly via Terraform**

Replace `providers/aws/accounts/personal/vista-hackathon-2026/main.tf` with:

```hcl
data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/org"
  }
}

resource "aws_organizations_account" "this" {
  name      = "vista-hackathon-2026"
  email     = var.account_email
  parent_id = data.terraform_remote_state.org.outputs.personal_ou_id

  lifecycle {
    prevent_destroy = true
  }
}

data "terraform_remote_state" "management" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/management"
  }
}

data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "github"
  }
}

data "terraform_remote_state" "pagerduty" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "pagerduty"
  }
}

module "baseline" {
  source = "../../../modules/baseline"

  providers = {
    aws = aws.account
  }

  account_name              = "vista-hackathon-2026"
  region                    = var.region
  github_repo               = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount             = var.budget_amount
  budget_thresholds         = var.budget_thresholds
  notification_email        = coalesce(var.notification_email, data.terraform_remote_state.management.outputs.notification_email)
  pagerduty_integration_key = data.terraform_remote_state.pagerduty.outputs.aws_integration_key
}
```

- [ ] **Step 4: Overwrite `variables.tf` to match (drop the stale `account_id` variable, add `account_email`)**

Replace `providers/aws/accounts/personal/vista-hackathon-2026/variables.tf` with:

```hcl
variable "account_email" {
  type        = string
  description = "Root email address for the vista-hackathon-2026 AWS account"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD for this account"
  default     = 10
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds triggering SNS alerts (e.g. [0.5, 0.9, 1.0])"
  default     = [0.5, 0.9, 1.0]
}

variable "notification_email" {
  type        = string
  description = "Email address for budget alert SNS subscription. Defaults to the management account's notification_email if not set."
  default     = null
}
```

- [ ] **Step 5: Update `terraform.tfvars.example` and create `terraform.tfvars`**

Replace `providers/aws/accounts/personal/vista-hackathon-2026/terraform.tfvars.example` with:

```hcl
account_email     = "aditya+aws-vista-hackathon-2026@tapshalkar.com"
region            = "us-east-1"
budget_amount     = 100
budget_thresholds = [0.5, 0.9, 1.0]
# notification_email = "override@example.com"  # inherits from management account if unset
```

Then create the real (gitignored) `terraform.tfvars` with the same content:

```bash
cd providers/aws/accounts/personal/vista-hackathon-2026
cp terraform.tfvars.example terraform.tfvars
```

- [ ] **Step 6: Format and validate**

```bash
terraform fmt -recursive
terraform init -backend-config=backend.hcl
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 7: Dry-run plan**

> Requires the AWS re-authentication from the Prerequisite section above — run `aws sts get-caller-identity` first and confirm it succeeds.

```bash
terraform plan
```

Expected: plan shows `aws_organizations_account.this` and the baseline module's resources (SNS topic, budget, IAM OIDC provider/role) to be **created**. No errors. Do not apply yet — that's Task 4.

- [ ] **Step 8: Commit**

```bash
cd /Users/adityatapshalkar/Documents/Dev/Repos/core-infra
git add providers/aws/accounts/personal/vista-hackathon-2026 providers/github/main.tf Makefile scripts/tf-all.sh
git commit -m "$(cat <<'EOF'
feat(aws/vista-hackathon-2026): scaffold new personal account for hackathon

Follows the Terraform-managed account-creation pattern used by
tapshalkar-com-sandbox rather than the older manual-creation flow the
scaffolding script still generates. $100/mo budget with tiered alerts.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Apply the GCP project

**Files:** none (applies Task 1's configuration)

**Interfaces:**
- Consumes: Task 1's validated configuration.
- Produces: a live GCP project `vista-hackathon-2026` with `workload_identity_provider` and `github_actions_service_account_email` outputs, consumed by Task 5.

- [ ] **Step 1: Confirm with the user before applying**

This creates a real, billable GCP project. Show the `terraform plan` output from Task 1 Step 4 (or re-run `terraform plan` if time has passed) and get explicit go-ahead before proceeding.

- [ ] **Step 2: Apply**

```bash
cd providers/gcp/projects/personal/vista-hackathon-2026
terraform apply
```

Expected: prompts `Enter a value:` for the `yes` confirmation; after confirming, ends with `Apply complete! Resources: N added, 0 changed, 0 destroyed.`

- [ ] **Step 3: Capture outputs for Task 5**

```bash
terraform output workload_identity_provider
terraform output github_actions_service_account_email
```

Expected: both print non-empty resource identifiers (used by GitHub Actions secrets in Task 5).

---

### Task 4: Apply the AWS account

**Files:** none (applies Task 2's configuration)

**Interfaces:**
- Consumes: Task 2's validated configuration.
- Produces: a live AWS member account `vista-hackathon-2026` with `account_id` and `github_actions_role_arn` outputs, consumed by Task 5.

- [ ] **Step 1: Confirm AWS re-authentication and confirm with the user before applying**

Run `aws sts get-caller-identity` — if it still fails, stop and ask the user to re-authenticate (see Prerequisite section). This creates a real AWS member account under the organization (accounts can take up to ~90 days to fully close if later removed) — get explicit go-ahead before proceeding, showing the plan from Task 2 Step 7.

- [ ] **Step 2: Apply**

```bash
cd providers/aws/accounts/personal/vista-hackathon-2026
terraform apply
```

Expected: prompts for `yes` confirmation; ends with `Apply complete! Resources: N added, 0 changed, 0 destroyed.` Account creation via `aws_organizations_account` can take a minute or two to complete inside Terraform's create step — this is normal.

- [ ] **Step 3: Capture outputs for Task 5**

```bash
terraform output account_id
terraform output github_actions_role_arn
```

Expected: both print non-empty values.

---

### Task 5: Publish GitHub Actions secrets and document manual follow-ups

**Files:**
- Modify: none (applies already-committed `providers/github/main.tf` changes from Task 2)

**Interfaces:**
- Consumes: Task 3's GCP outputs, Task 4's AWS outputs (both already wired automatically via `terraform_remote_state` in `providers/github/main.tf` — no manual copy-paste).

- [ ] **Step 1: Apply the github root to publish the new AWS secret**

```bash
cd /Users/adityatapshalkar/Documents/Dev/Repos/core-infra/providers/github
terraform init -backend-config=backend.hcl
terraform plan
```

Expected: plan shows one new resource — `github_actions_secret.aws_vista_hackathon_2026_role_arn` — to be created. Confirm with the user, then:

```bash
terraform apply
```

- [ ] **Step 2: Verify budget alerting works**

Check that the budget-alert email (and PagerDuty, if the integration key resolved) subscription confirmations arrived for both new resources — GCP via Cloud Monitoring notification channel, AWS via the SNS topic subscription. No code changes; this is a manual visual check in each provider's console.

- [ ] **Step 3: Document the one AWS manual step that Terraform can't automate**

Bedrock foundation-model access (e.g., Anthropic Claude models) must be requested once per AWS account/region via the console before any team member can invoke those models:

1. Go to the AWS Console → Bedrock → **Model access** (region: `us-east-1`, account: the new `vista-hackathon-2026` account ID from Task 4).
2. Request access to the foundation models you expect to use.
3. Approval is typically instant for on-demand models.

No Terraform resource exists for this step as of this repo's AWS provider version — it's a one-time manual action to complete before the event.

- [ ] **Step 4: Final commit (if `providers/github` state changes need no code commit, skip; otherwise commit any leftover formatting changes)**

```bash
cd /Users/adityatapshalkar/Documents/Dev/Repos/core-infra
git status
```

If clean (expected — Task 5 only applies already-committed config), no commit needed here.

---

## Self-Review Notes

- **Spec coverage:** Section 1 (accounts) → Tasks 1–2 (scaffold) + 3–4 (apply). Section 2 (superseded/out of scope) → no task, correctly omitted. Section 3 (AI service enablement) → Task 1 Step 2 (`enabled_apis`) and Task 5 Step 3 (Bedrock manual note). Section 4 (budget/lifecycle) → Task 1 Step 2 and Task 2 Step 5 (`budget_amount = 100`); manual teardown is documented behavior, not a task (non-goal, no code needed). Testing/Verification section → Task 1 Steps 3–4, Task 2 Steps 6–7 (validate/plan), Task 5 Step 2 (manual budget alert check).
- **Script staleness:** flagged inline in Task 2 rather than silently deviating — the plan explains why it overwrites four of the script's generated files.
- **No placeholders:** all file contents are complete, copy-pasteable Terraform, not summaries.
