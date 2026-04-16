# AWS Org + Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring a pre-existing AWS Organization under Terraform management, create a GCP-style OU hierarchy, add a new personal member account, set up centralized budgets + PagerDuty alerts on the management account, wire GitHub Actions OIDC into every account, and extend the github provider root to publish AWS role ARNs as Actions secrets.

**Architecture:** An `aws/org/` root manages OUs and member account placement. A reusable `aws/modules/baseline/` sets up GitHub OIDC in member accounts. The management account root owns all billing (per-linked-account budgets → SNS → PagerDuty). Each member account root calls the baseline module via `assume_role`. The github provider root is extended to read all AWS account states and write `AWS_<NAME>_ROLE_ARN` secrets.

**Tech Stack:** Terraform >= 1.5, `hashicorp/aws ~> 5.0`, `integrations/github ~> 6.0`, GCS remote state (bucket: `tapshalkar-com-tfstate`), PagerDuty Events API v2

---

## File Map

**Created:**
- `providers/aws/org/versions.tf`
- `providers/aws/org/backend.tf`
- `providers/aws/org/variables.tf`
- `providers/aws/org/main.tf`
- `providers/aws/org/outputs.tf`
- `providers/aws/org/terraform.tfvars.example`
- `providers/aws/modules/baseline/versions.tf`
- `providers/aws/modules/baseline/variables.tf`
- `providers/aws/modules/baseline/oidc.tf`
- `providers/aws/modules/baseline/outputs.tf`
- `providers/aws/accounts/management/versions.tf`
- `providers/aws/accounts/management/backend.tf`
- `providers/aws/accounts/management/variables.tf`
- `providers/aws/accounts/management/main.tf`
- `providers/aws/accounts/management/notifications.tf`
- `providers/aws/accounts/management/budgets.tf`
- `providers/aws/accounts/management/oidc.tf`
- `providers/aws/accounts/management/outputs.tf`
- `providers/aws/accounts/management/terraform.tfvars.example`
- `providers/aws/accounts/personal/versions.tf`
- `providers/aws/accounts/personal/backend.tf`
- `providers/aws/accounts/personal/variables.tf`
- `providers/aws/accounts/personal/main.tf`
- `providers/aws/accounts/personal/outputs.tf`
- `providers/aws/accounts/personal/terraform.tfvars.example`
- `providers/aws/accounts/certs/account-1/` — same 5 files
- `providers/aws/accounts/certs/account-2/` — same 5 files
- `providers/aws/accounts/projects/side-project/` — same 5 files

**Modified:**
- `providers/aws/.gitkeep` — deleted (replaced by real directory content)
- `providers/github/main.tf` — add 5 remote state data sources + 5 secrets + 1 variable
- `providers/github/outputs.tf` — add `aws_region` output

---

## Task 1: `providers/aws/org/` — Org Hierarchy Root

**Files:**
- Create: `providers/aws/org/versions.tf`
- Create: `providers/aws/org/backend.tf`
- Create: `providers/aws/org/variables.tf`
- Create: `providers/aws/org/main.tf`
- Create: `providers/aws/org/outputs.tf`
- Create: `providers/aws/org/terraform.tfvars.example`

- [ ] **Step 1: Write `providers/aws/org/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

- [ ] **Step 2: Write `providers/aws/org/backend.tf`**

```hcl
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/org"
  }
}
```

- [ ] **Step 3: Write `providers/aws/org/variables.tf`**

```hcl
variable "aws_region" {
  type        = string
  description = "AWS region for the provider (org-level resources are global, but a region is required)"
  default     = "us-east-1"
}

variable "certs_1_account_name" {
  type        = string
  description = "Display name of the first certs account (must match existing account name exactly)"
}

variable "certs_1_account_email" {
  type        = string
  description = "Root email of the first certs account (must match the email used when the account was created)"
}

variable "certs_2_account_name" {
  type        = string
  description = "Display name of the second certs account (must match existing account name exactly)"
}

variable "certs_2_account_email" {
  type        = string
  description = "Root email of the second certs account (must match the email used when the account was created)"
}

variable "side_project_account_name" {
  type        = string
  description = "Display name of the side-project account (must match existing account name exactly)"
}

variable "side_project_account_email" {
  type        = string
  description = "Root email of the side-project account (must match the email used when the account was created)"
}

variable "personal_account_name" {
  type        = string
  description = "Display name for the new personal member account"
}

variable "personal_account_email" {
  type        = string
  description = "Root email for the new personal member account (must be a globally unique email never registered with AWS)"
}
```

- [ ] **Step 4: Write `providers/aws/org/main.tf`**

```hcl
data "aws_organizations_organization" "this" {}

resource "aws_organizations_organizational_unit" "personal" {
  name      = "personal"
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "certs" {
  name      = "certs"
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "projects" {
  name      = "projects"
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "certs_1" {
  name      = var.certs_1_account_name
  email     = var.certs_1_account_email
  parent_id = aws_organizations_organizational_unit.certs.id

  lifecycle {
    # iam_user_access_to_billing is set at account creation and not reliably
    # readable via API — ignoring prevents spurious diffs on import.
    ignore_changes = [iam_user_access_to_billing]
  }
}

resource "aws_organizations_account" "certs_2" {
  name      = var.certs_2_account_name
  email     = var.certs_2_account_email
  parent_id = aws_organizations_organizational_unit.certs.id

  lifecycle {
    ignore_changes = [iam_user_access_to_billing]
  }
}

resource "aws_organizations_account" "side_project" {
  name      = var.side_project_account_name
  email     = var.side_project_account_email
  parent_id = aws_organizations_organizational_unit.projects.id

  lifecycle {
    ignore_changes = [iam_user_access_to_billing]
  }
}

resource "aws_organizations_account" "personal" {
  name      = var.personal_account_name
  email     = var.personal_account_email
  parent_id = aws_organizations_organizational_unit.personal.id
}
```

- [ ] **Step 5: Write `providers/aws/org/outputs.tf`**

```hcl
output "root_id" {
  description = "ID of the organization root"
  value       = data.aws_organizations_organization.this.roots[0].id
}

output "personal_ou_id" {
  description = "ID of the personal/ OU"
  value       = aws_organizations_organizational_unit.personal.id
}

output "certs_ou_id" {
  description = "ID of the certs/ OU"
  value       = aws_organizations_organizational_unit.certs.id
}

output "projects_ou_id" {
  description = "ID of the projects/ OU"
  value       = aws_organizations_organizational_unit.projects.id
}

output "personal_account_id" {
  description = "AWS account ID of the new personal member account"
  value       = aws_organizations_account.personal.id
}

output "certs_account_1_id" {
  description = "AWS account ID of the first certs account"
  value       = aws_organizations_account.certs_1.id
}

output "certs_account_2_id" {
  description = "AWS account ID of the second certs account"
  value       = aws_organizations_account.certs_2.id
}

output "side_project_account_id" {
  description = "AWS account ID of the side-project account"
  value       = aws_organizations_account.side_project.id
}
```

- [ ] **Step 6: Write `providers/aws/org/terraform.tfvars.example`**

```hcl
aws_region = "us-east-1"

# Existing accounts — name and email must exactly match what's in the AWS console.
# Find these in: AWS Console → Organizations → Accounts
certs_1_account_name  = "my-certs-1"
certs_1_account_email = "aws+certs-1@example.com"

certs_2_account_name  = "my-certs-2"
certs_2_account_email = "aws+certs-2@example.com"

side_project_account_name  = "my-side-project"
side_project_account_email = "aws+side-project@example.com"

# New personal member account — this email must never have been registered with AWS before.
# Using email aliasing (e.g., root+aws-personal@yourdomain.com) is recommended.
personal_account_name  = "personal"
personal_account_email = "aws+personal@example.com"
```

- [ ] **Step 7: Remove the placeholder `.gitkeep`**

```bash
rm providers/aws/.gitkeep
```

- [ ] **Step 8: Copy tfvars and fill in real values**

```bash
cp providers/aws/org/terraform.tfvars.example providers/aws/org/terraform.tfvars
# Edit terraform.tfvars with the real account names and emails from AWS Console → Organizations → Accounts
```

- [ ] **Step 9: Initialize and validate**

```bash
cd providers/aws/org
terraform init -backend-config="bucket=tapshalkar-com-tfstate"
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 10: Import existing OUs (only if they already exist)**

Check first:
```bash
aws organizations list-organizational-units-for-parent \
  --parent-id $(aws organizations list-roots --query 'Roots[0].Id' --output text) \
  --query 'OrganizationalUnits[*].{Name:Name,Id:Id}' \
  --output table
```

If the OUs already exist, import them. If not, skip this step — Terraform will create them.
```bash
terraform import aws_organizations_organizational_unit.personal <PERSONAL_OU_ID>
terraform import aws_organizations_organizational_unit.certs    <CERTS_OU_ID>
terraform import aws_organizations_organizational_unit.projects <PROJECTS_OU_ID>
```

- [ ] **Step 11: Import existing member accounts**

Get account IDs:
```bash
aws organizations list-accounts \
  --query 'Accounts[*].{Name:Name,Id:Id,Status:Status}' \
  --output table
```

Import each existing account (do NOT import the management account — it's a data source):
```bash
terraform import aws_organizations_account.certs_1      <CERTS_1_ACCOUNT_ID>
terraform import aws_organizations_account.certs_2      <CERTS_2_ACCOUNT_ID>
terraform import aws_organizations_account.side_project <SIDE_PROJECT_ACCOUNT_ID>
```

- [ ] **Step 12: Plan and review**

```bash
terraform plan
```

Expected: existing accounts show no changes (or minor tag diffs). OUs show as "to create" if not imported. Personal account shows as "to create". Review carefully — no account should be destroyed.

- [ ] **Step 13: Apply**

```bash
terraform apply
```

Expected: OUs created (or confirmed), personal account created, existing accounts placed in OUs. Note the `personal_account_id` output — you'll need it in Task 4.

- [ ] **Step 14: Commit**

```bash
cd ../../..
git add providers/aws/org/
git commit -m "feat(aws/org): add org root — OUs, member account placement, personal account"
```

---

## Task 2: `providers/aws/modules/baseline/` — OIDC Module

**Files:**
- Create: `providers/aws/modules/baseline/versions.tf`
- Create: `providers/aws/modules/baseline/variables.tf`
- Create: `providers/aws/modules/baseline/oidc.tf`
- Create: `providers/aws/modules/baseline/outputs.tf`

- [ ] **Step 1: Write `providers/aws/modules/baseline/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 2: Write `providers/aws/modules/baseline/variables.tf`**

```hcl
variable "account_name" {
  type        = string
  description = "Logical name of this account (used in IAM role name, e.g. 'personal', 'certs-1')"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in 'owner/repo' format. OIDC tokens are scoped to this repo only."
}
```

- [ ] **Step 3: Write `providers/aws/modules/baseline/oidc.tf`**

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprints for the intermediate CAs used by token.actions.githubusercontent.com.
  # Both are included to cover the original cert and GitHub's 2023 rotation.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1b511abead59c6ce207077c0bf0e0043b1382612",
  ]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-${var.account_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
```

- [ ] **Step 4: Write `providers/aws/modules/baseline/outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_actions.arn
}
```

- [ ] **Step 5: Validate module**

```bash
cd providers/aws/modules/baseline
terraform init
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Commit**

```bash
cd ../../../..
git add providers/aws/modules/
git commit -m "feat(aws/modules/baseline): add OIDC module for GitHub Actions authentication"
```

---

## Task 3: `providers/aws/accounts/management/` — Management Account

**Files:**
- Create: `providers/aws/accounts/management/versions.tf`
- Create: `providers/aws/accounts/management/backend.tf`
- Create: `providers/aws/accounts/management/variables.tf`
- Create: `providers/aws/accounts/management/main.tf`
- Create: `providers/aws/accounts/management/notifications.tf`
- Create: `providers/aws/accounts/management/budgets.tf`
- Create: `providers/aws/accounts/management/oidc.tf`
- Create: `providers/aws/accounts/management/outputs.tf`
- Create: `providers/aws/accounts/management/terraform.tfvars.example`

- [ ] **Step 1: Write `providers/aws/accounts/management/versions.tf`**

The management account uses default credentials (no `assume_role`) — it IS the org root.

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

- [ ] **Step 2: Write `providers/aws/accounts/management/backend.tf`**

```hcl
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/management"
  }
}
```

- [ ] **Step 3: Write `providers/aws/accounts/management/variables.tf`**

```hcl
variable "aws_region" {
  type        = string
  description = "AWS region for management account resources (SNS topics are regional)"
  default     = "us-east-1"
}

variable "budget_amounts" {
  type        = map(number)
  description = <<-EOT
    Monthly budget cap in USD per linked account.
    Keys must be: personal, certs_1, certs_2, side_project.
    These keys correspond to the aws/org remote state outputs.
  EOT
  default = {
    personal     = 10
    certs_1      = 5
    certs_2      = 5
    side_project = 10
  }
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds triggering SNS alerts (e.g. [0.5, 0.9, 1.0] = 50%, 90%, 100%)"
  default     = [0.5, 0.9, 1.0]

  validation {
    condition     = alltrue([for t in var.budget_thresholds : t > 0 && t <= 1.5])
    error_message = "Budget thresholds must be between 0 and 1.5."
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in 'owner/repo' format for OIDC trust policy."
}
```

- [ ] **Step 4: Write `providers/aws/accounts/management/main.tf`**

```hcl
data "terraform_remote_state" "pagerduty" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "pagerduty"
  }
}

data "terraform_remote_state" "aws_org" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/org"
  }
}
```

- [ ] **Step 5: Write `providers/aws/accounts/management/notifications.tf`**

```hcl
resource "aws_sns_topic" "budget_alerts" {
  name = "budget-alerts"
}

resource "aws_sns_topic_policy" "budget_alerts" {
  arn = aws_sns_topic.budget_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.budget_alerts.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/${data.terraform_remote_state.pagerduty.outputs.integration_key}/enqueue"

  # PagerDuty auto-confirms HTTPS SNS subscriptions — no manual confirmation needed.
  endpoint_auto_confirms = true
}
```

- [ ] **Step 6: Write `providers/aws/accounts/management/budgets.tf`**

```hcl
locals {
  # Map of logical account name → account ID, sourced from aws/org remote state.
  # Keys must match the keys in var.budget_amounts.
  budgeted_accounts = {
    personal     = data.terraform_remote_state.aws_org.outputs.personal_account_id
    certs_1      = data.terraform_remote_state.aws_org.outputs.certs_account_1_id
    certs_2      = data.terraform_remote_state.aws_org.outputs.certs_account_2_id
    side_project = data.terraform_remote_state.aws_org.outputs.side_project_account_id
  }
}

resource "aws_budgets_budget" "per_account" {
  for_each = local.budgeted_accounts

  name              = "${each.key}-monthly"
  budget_type       = "COST"
  limit_amount      = tostring(var.budget_amounts[each.key])
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  cost_filter {
    name   = "LinkedAccount"
    values = [each.value]
  }

  dynamic "notification" {
    for_each = var.budget_thresholds
    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value * 100
      threshold_type            = "PERCENTAGE"
      notification_type         = "ACTUAL"
      subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
    }
  }
}
```

- [ ] **Step 7: Write `providers/aws/accounts/management/oidc.tf`**

The management account sets up its own OIDC directly (not via the shared module, since it uses default credentials rather than `assume_role`).

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1b511abead59c6ce207077c0bf0e0043b1382612",
  ]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-management"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
```

- [ ] **Step 8: Write `providers/aws/accounts/management/outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (management account)"
  value       = aws_iam_role.github_actions.arn
}
```

- [ ] **Step 9: Write `providers/aws/accounts/management/terraform.tfvars.example`**

```hcl
aws_region = "us-east-1"

# Monthly budget caps per linked account (USD).
# Update these to match your expected spend per account.
budget_amounts = {
  personal     = 10
  certs_1      = 5
  certs_2      = 5
  side_project = 10
}

budget_thresholds = [0.5, 0.9, 1.0]

github_repo = "adityataps/core-infra"
```

- [ ] **Step 10: Copy tfvars and fill in values**

```bash
cp providers/aws/accounts/management/terraform.tfvars.example \
   providers/aws/accounts/management/terraform.tfvars
# Edit budget_amounts to match your expected spend per account
```

- [ ] **Step 11: Initialize and validate**

```bash
cd providers/aws/accounts/management
terraform init -backend-config="bucket=tapshalkar-com-tfstate"
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 12: Plan and apply**

Requires Task 1 (`aws/org`) to have been applied first so the remote state exists.

```bash
terraform plan
terraform apply
```

Expected: SNS topic, SNS policy, PagerDuty subscription, 4 budgets (personal/certs_1/certs_2/side_project), OIDC provider, IAM role — all created.

- [ ] **Step 13: Commit**

```bash
cd ../../../..
git add providers/aws/accounts/management/
git commit -m "feat(aws/accounts/management): add budgets, SNS, PagerDuty, and OIDC"
```

---

## Task 4: `providers/aws/accounts/personal/` — Personal Member Account

**Files:**
- Create: `providers/aws/accounts/personal/versions.tf`
- Create: `providers/aws/accounts/personal/backend.tf`
- Create: `providers/aws/accounts/personal/variables.tf`
- Create: `providers/aws/accounts/personal/main.tf`
- Create: `providers/aws/accounts/personal/outputs.tf`
- Create: `providers/aws/accounts/personal/terraform.tfvars.example`

- [ ] **Step 1: Write `providers/aws/accounts/personal/versions.tf`**

`assume_role` uses `var.account_id` — provider blocks cannot reference data sources, so the account ID is passed as a variable (filled from `aws/org` outputs after Task 1 applies).

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
  }
}
```

- [ ] **Step 2: Write `providers/aws/accounts/personal/backend.tf`**

```hcl
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/personal"
  }
}
```

- [ ] **Step 3: Write `providers/aws/accounts/personal/variables.tf`**

```hcl
variable "account_id" {
  type        = string
  description = "AWS account ID of the personal member account. Get from: terraform output -raw personal_account_id (in providers/aws/org/)"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}
```

- [ ] **Step 4: Write `providers/aws/accounts/personal/main.tf`**

```hcl
data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "github"
  }
}

module "baseline" {
  source = "../../../modules/baseline"

  account_name = "personal"
  region       = var.region
  github_repo  = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
}
```

- [ ] **Step 5: Write `providers/aws/accounts/personal/outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (personal account)"
  value       = module.baseline.github_actions_role_arn
}
```

- [ ] **Step 6: Write `providers/aws/accounts/personal/terraform.tfvars.example`**

```hcl
# Get account_id from: cd providers/aws/org && terraform output personal_account_id
account_id = "123456789012"
region     = "us-east-1"
```

- [ ] **Step 7: Copy tfvars and fill in account_id**

```bash
cp providers/aws/accounts/personal/terraform.tfvars.example \
   providers/aws/accounts/personal/terraform.tfvars
# Set account_id to the value from: cd providers/aws/org && terraform output personal_account_id
```

- [ ] **Step 8: Initialize, validate, and apply**

```bash
cd providers/aws/accounts/personal
terraform init -backend-config="bucket=tapshalkar-com-tfstate"
terraform validate
terraform plan
terraform apply
```

Expected: OIDC provider + IAM role (`github-actions-personal`) created in the personal account.

- [ ] **Step 9: Commit**

```bash
cd ../../../..
git add providers/aws/accounts/personal/
git commit -m "feat(aws/accounts/personal): add personal member account baseline (OIDC)"
```

---

## Task 5: `providers/aws/accounts/certs/account-1/` — Certs Account 1

**Files:**
- Create: `providers/aws/accounts/certs/account-1/versions.tf`
- Create: `providers/aws/accounts/certs/account-1/backend.tf`
- Create: `providers/aws/accounts/certs/account-1/variables.tf`
- Create: `providers/aws/accounts/certs/account-1/main.tf`
- Create: `providers/aws/accounts/certs/account-1/outputs.tf`
- Create: `providers/aws/accounts/certs/account-1/terraform.tfvars.example`

- [ ] **Step 1: Write `providers/aws/accounts/certs/account-1/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
  }
}
```

- [ ] **Step 2: Write `providers/aws/accounts/certs/account-1/backend.tf`**

```hcl
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/certs/account-1"
  }
}
```

- [ ] **Step 3: Write `providers/aws/accounts/certs/account-1/variables.tf`**

```hcl
variable "account_id" {
  type        = string
  description = "AWS account ID of the first certs account. Get from: terraform output -raw certs_account_1_id (in providers/aws/org/)"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}
```

- [ ] **Step 4: Write `providers/aws/accounts/certs/account-1/main.tf`**

```hcl
data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "github"
  }
}

module "baseline" {
  source = "../../../../modules/baseline"

  account_name = "certs-1"
  region       = var.region
  github_repo  = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
}
```

- [ ] **Step 5: Write `providers/aws/accounts/certs/account-1/outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (certs account 1)"
  value       = module.baseline.github_actions_role_arn
}
```

- [ ] **Step 6: Write `providers/aws/accounts/certs/account-1/terraform.tfvars.example`**

```hcl
# Get account_id from: cd providers/aws/org && terraform output certs_account_1_id
account_id = "123456789012"
region     = "us-east-1"
```

- [ ] **Step 7: Copy tfvars and fill in account_id**

```bash
cp providers/aws/accounts/certs/account-1/terraform.tfvars.example \
   providers/aws/accounts/certs/account-1/terraform.tfvars
# Set account_id to the value from: cd providers/aws/org && terraform output certs_account_1_id
```

- [ ] **Step 8: Verify OrganizationAccountAccessRole exists in this account**

If this account was invited to the org (not created via Organizations), the role may not exist. Check:
```bash
aws iam get-role --role-name OrganizationAccountAccessRole \
  --query 'Role.Arn' --output text \
  --region us-east-1 \
  $(aws sts assume-role \
    --role-arn "arn:aws:iam::<CERTS_1_ACCOUNT_ID>:role/OrganizationAccountAccessRole" \
    --role-session-name check 2>/dev/null || echo "ROLE_MISSING")
```

If missing, create it manually in the certs-1 account via AWS Console → IAM → Roles → Create role → AWS account → management account ID → AdministratorAccess.

- [ ] **Step 9: Initialize, validate, and apply**

```bash
cd providers/aws/accounts/certs/account-1
terraform init -backend-config="bucket=tapshalkar-com-tfstate"
terraform validate
terraform plan
terraform apply
```

Expected: OIDC provider + IAM role (`github-actions-certs-1`) created in the certs-1 account.

- [ ] **Step 10: Commit**

```bash
cd ../../../../..
git add providers/aws/accounts/certs/account-1/
git commit -m "feat(aws/accounts/certs-1): add certs account 1 baseline (OIDC)"
```

---

## Task 6: `providers/aws/accounts/certs/account-2/` — Certs Account 2

**Files:**
- Create: `providers/aws/accounts/certs/account-2/versions.tf`
- Create: `providers/aws/accounts/certs/account-2/backend.tf`
- Create: `providers/aws/accounts/certs/account-2/variables.tf`
- Create: `providers/aws/accounts/certs/account-2/main.tf`
- Create: `providers/aws/accounts/certs/account-2/outputs.tf`
- Create: `providers/aws/accounts/certs/account-2/terraform.tfvars.example`

- [ ] **Step 1: Write `providers/aws/accounts/certs/account-2/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
  }
}
```

- [ ] **Step 2: Write `providers/aws/accounts/certs/account-2/backend.tf`**

```hcl
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/certs/account-2"
  }
}
```

- [ ] **Step 3: Write `providers/aws/accounts/certs/account-2/variables.tf`**

```hcl
variable "account_id" {
  type        = string
  description = "AWS account ID of the second certs account. Get from: terraform output -raw certs_account_2_id (in providers/aws/org/)"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}
```

- [ ] **Step 4: Write `providers/aws/accounts/certs/account-2/main.tf`**

```hcl
data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "github"
  }
}

module "baseline" {
  source = "../../../../modules/baseline"

  account_name = "certs-2"
  region       = var.region
  github_repo  = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
}
```

- [ ] **Step 5: Write `providers/aws/accounts/certs/account-2/outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (certs account 2)"
  value       = module.baseline.github_actions_role_arn
}
```

- [ ] **Step 6: Write `providers/aws/accounts/certs/account-2/terraform.tfvars.example`**

```hcl
# Get account_id from: cd providers/aws/org && terraform output certs_account_2_id
account_id = "123456789012"
region     = "us-east-1"
```

- [ ] **Step 7: Copy tfvars, fill in account_id, verify OrganizationAccountAccessRole, init + apply**

```bash
cp providers/aws/accounts/certs/account-2/terraform.tfvars.example \
   providers/aws/accounts/certs/account-2/terraform.tfvars
# Set account_id from: cd providers/aws/org && terraform output certs_account_2_id

cd providers/aws/accounts/certs/account-2
terraform init -backend-config="bucket=tapshalkar-com-tfstate"
terraform validate
terraform plan
terraform apply
```

Expected: OIDC provider + IAM role (`github-actions-certs-2`) created in the certs-2 account.

- [ ] **Step 8: Commit**

```bash
cd ../../../../..
git add providers/aws/accounts/certs/account-2/
git commit -m "feat(aws/accounts/certs-2): add certs account 2 baseline (OIDC)"
```

---

## Task 7: `providers/aws/accounts/projects/side-project/` — Side Project Account

**Files:**
- Create: `providers/aws/accounts/projects/side-project/versions.tf`
- Create: `providers/aws/accounts/projects/side-project/backend.tf`
- Create: `providers/aws/accounts/projects/side-project/variables.tf`
- Create: `providers/aws/accounts/projects/side-project/main.tf`
- Create: `providers/aws/accounts/projects/side-project/outputs.tf`
- Create: `providers/aws/accounts/projects/side-project/terraform.tfvars.example`

- [ ] **Step 1: Write `providers/aws/accounts/projects/side-project/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
  }
}
```

- [ ] **Step 2: Write `providers/aws/accounts/projects/side-project/backend.tf`**

```hcl
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/projects/side-project"
  }
}
```

- [ ] **Step 3: Write `providers/aws/accounts/projects/side-project/variables.tf`**

```hcl
variable "account_id" {
  type        = string
  description = "AWS account ID of the side-project account. Get from: terraform output -raw side_project_account_id (in providers/aws/org/)"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}
```

- [ ] **Step 4: Write `providers/aws/accounts/projects/side-project/main.tf`**

```hcl
data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "github"
  }
}

module "baseline" {
  source = "../../../../modules/baseline"

  account_name = "side-project"
  region       = var.region
  github_repo  = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
}
```

- [ ] **Step 5: Write `providers/aws/accounts/projects/side-project/outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (side-project account)"
  value       = module.baseline.github_actions_role_arn
}
```

- [ ] **Step 6: Write `providers/aws/accounts/projects/side-project/terraform.tfvars.example`**

```hcl
# Get account_id from: cd providers/aws/org && terraform output side_project_account_id
account_id = "123456789012"
region     = "us-east-1"
```

- [ ] **Step 7: Copy tfvars, fill in account_id, verify OrganizationAccountAccessRole, init + apply**

```bash
cp providers/aws/accounts/projects/side-project/terraform.tfvars.example \
   providers/aws/accounts/projects/side-project/terraform.tfvars
# Set account_id from: cd providers/aws/org && terraform output side_project_account_id

cd providers/aws/accounts/projects/side-project
terraform init -backend-config="bucket=tapshalkar-com-tfstate"
terraform validate
terraform plan
terraform apply
```

Expected: OIDC provider + IAM role (`github-actions-side-project`) created in the side-project account.

- [ ] **Step 8: Commit**

```bash
cd ../../../../..
git add providers/aws/accounts/projects/side-project/
git commit -m "feat(aws/accounts/side-project): add side-project account baseline (OIDC)"
```

---

## Task 8: Extend `providers/github/` — AWS Secrets

**Files:**
- Modify: `providers/github/main.tf`
- Modify: `providers/github/outputs.tf`

Requires all account roots (Tasks 3–7) to have been applied first so their remote states exist.

- [ ] **Step 1: Add AWS remote state data sources and secrets to `providers/github/main.tf`**

Append to the existing `providers/github/main.tf` (after the current `github_actions_secret.gcp_service_account` resource):

```hcl
# ── AWS remote states ──────────────────────────────────────────────────────────

data "terraform_remote_state" "aws_management" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/management"
  }
}

data "terraform_remote_state" "aws_personal" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/personal"
  }
}

data "terraform_remote_state" "aws_certs_1" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/certs/account-1"
  }
}

data "terraform_remote_state" "aws_certs_2" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/certs/account-2"
  }
}

data "terraform_remote_state" "aws_side_project" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/projects/side-project"
  }
}

# ── AWS Actions secrets ────────────────────────────────────────────────────────

resource "github_actions_secret" "aws_management_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_MANAGEMENT_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_management.outputs.github_actions_role_arn
}

resource "github_actions_secret" "aws_personal_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_PERSONAL_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_personal.outputs.github_actions_role_arn
}

resource "github_actions_secret" "aws_certs_1_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_CERTS_1_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_certs_1.outputs.github_actions_role_arn
}

resource "github_actions_secret" "aws_certs_2_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_CERTS_2_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_certs_2.outputs.github_actions_role_arn
}

resource "github_actions_secret" "aws_side_project_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_SIDE_PROJECT_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_side_project.outputs.github_actions_role_arn
}

# ── AWS Actions variables ──────────────────────────────────────────────────────

resource "github_actions_variable" "aws_region" {
  repository    = data.github_repository.core_infra.name
  variable_name = "AWS_REGION"
  value         = "us-east-1"
}
```

- [ ] **Step 2: Add `aws_region` to `providers/github/outputs.tf`**

Append to the existing file:

```hcl
output "aws_region" {
  description = "Default AWS region used across all AWS accounts"
  value       = github_actions_variable.aws_region.value
}
```

- [ ] **Step 3: Validate**

```bash
cd providers/github
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 4: Plan and apply**

```bash
terraform plan
terraform apply
```

Expected: 5 new `github_actions_secret` resources and 1 `github_actions_variable` created. Verify in GitHub: Settings → Secrets and variables → Actions — you should see `AWS_MANAGEMENT_ROLE_ARN`, `AWS_PERSONAL_ROLE_ARN`, `AWS_CERTS_1_ROLE_ARN`, `AWS_CERTS_2_ROLE_ARN`, `AWS_SIDE_PROJECT_ROLE_ARN` as secrets, and `AWS_REGION` as a variable.

- [ ] **Step 5: Commit**

```bash
cd ../..
git add providers/github/main.tf providers/github/outputs.tf
git commit -m "feat(github): wire AWS account OIDC role ARNs as Actions secrets"
```
