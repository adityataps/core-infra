# AWS Org/Accounts Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the AWS provider so `org/` manages OUs only, each account root is self-contained with its own budgets, and account creation moves fully to `scripts/create-aws-account.sh`.

**Architecture:** Remove all `aws_organizations_account` resources from `org/`, fold budget + SNS infrastructure into `modules/baseline/`, update every account root to call the enhanced module, and rewrite the scaffold script to no longer touch org Terraform files.

**Tech Stack:** Terraform ~> 1.5, AWS provider ~> 5.0, GCS remote state backend, bash

---

## File Map

| File | Action | Notes |
|---|---|---|
| `providers/aws/org/main.tf` | Modify | Remove all `aws_organizations_account` resources |
| `providers/aws/org/variables.tf` | Modify | Remove all per-account name/email variables |
| `providers/aws/org/outputs.tf` | Modify | Remove all account ID outputs |
| `providers/aws/modules/baseline/budgets.tf` | Create | SNS topic + policy + email subscription + budget |
| `providers/aws/modules/baseline/variables.tf` | Modify | Add `budget_amount`, `budget_thresholds`, `notification_email` |
| `providers/aws/modules/baseline/outputs.tf` | Modify | Add `account_id`, `budget_alerts_sns_topic_arn` |
| `providers/aws/accounts/management/tapshalkar-com/main.tf` | Modify | Call baseline with new vars; read pagerduty remote state |
| `providers/aws/accounts/management/tapshalkar-com/notifications.tf` | Modify | Simplify to PagerDuty subscription only |
| `providers/aws/accounts/management/tapshalkar-com/variables.tf` | Modify | Remove budget_amounts map; add flat budget vars |
| `providers/aws/accounts/management/tapshalkar-com/outputs.tf` | Modify | Add `account_id` output |
| `providers/aws/accounts/management/tapshalkar-com/oidc.tf` | Delete | Moved into baseline module |
| `providers/aws/accounts/management/tapshalkar-com/budgets.tf` | Delete | Moved into baseline module |
| `providers/aws/accounts/personal/tapshalkar-com-personal/main.tf` | Modify | Add budget vars to module call |
| `providers/aws/accounts/personal/tapshalkar-com-personal/variables.tf` | Modify | Remove `account_id` org ref; add budget vars |
| `providers/aws/accounts/personal/tapshalkar-com-personal/outputs.tf` | Modify | Add `account_id` output |
| `providers/aws/accounts/personal/tapshalkar-com-sandbox/main.tf` | Modify | Add budget vars to module call |
| `providers/aws/accounts/personal/tapshalkar-com-sandbox/variables.tf` | Modify | Remove `account_id` org ref; add budget vars |
| `providers/aws/accounts/personal/tapshalkar-com-sandbox/outputs.tf` | Modify | Add `account_id` output |
| `providers/aws/accounts/certs/tapshalkar-com-certs/main.tf` | Modify | Add budget vars to module call |
| `providers/aws/accounts/certs/tapshalkar-com-certs/variables.tf` | Modify | Remove `account_id` org ref; add budget vars |
| `providers/aws/accounts/certs/tapshalkar-com-certs/outputs.tf` | Modify | Add `account_id` output |
| `providers/aws/accounts/personal/` (old standalone) | Delete | Entire directory |
| `providers/aws/accounts/projects/` | Delete | Entire directory (side-project) |
| `scripts/create-aws-account.sh` | Modify | Remove org patching; add budget vars to scaffold; use AWS CLI for account creation |

---

## Task 1: Remove old accounts from org Terraform state

Before touching any code, de-register the old `aws_organizations_account` resources from Terraform state so Terraform won't attempt to close live AWS accounts when the resources are removed from config.

**Files:** none (state only)

- [ ] **Step 1: Navigate to org root and verify state**

```bash
cd providers/aws/org
terraform state list | grep aws_organizations_account
```

Expected output (all 8 accounts):
```
aws_organizations_account.certs_1
aws_organizations_account.certs_2
aws_organizations_account.personal
aws_organizations_account.side_project
aws_organizations_account.tapshalkar_com
aws_organizations_account.tapshalkar_com_certs
aws_organizations_account.tapshalkar_com_personal
aws_organizations_account.tapshalkar_com_sandbox
```

- [ ] **Step 2: Remove old accounts from state**

```bash
terraform state rm aws_organizations_account.personal
terraform state rm aws_organizations_account.certs_1
terraform state rm aws_organizations_account.certs_2
terraform state rm aws_organizations_account.side_project
terraform state rm aws_organizations_account.tapshalkar_com
terraform state rm aws_organizations_account.tapshalkar_com_certs
terraform state rm aws_organizations_account.tapshalkar_com_personal
terraform state rm aws_organizations_account.tapshalkar_com_sandbox
```

Expected: each command prints `Removed aws_organizations_account.<name>` and exits 0.

- [ ] **Step 3: Confirm state is clean**

```bash
terraform state list | grep aws_organizations_account
```

Expected: no output (empty).

---

## Task 2: Refactor `org/` to OUs only

Remove all account resources, variables, and outputs. After this task, `org/` only manages the organization and its OUs.

**Files:**
- Modify: `providers/aws/org/main.tf`
- Modify: `providers/aws/org/variables.tf`
- Modify: `providers/aws/org/outputs.tf`

- [ ] **Step 1: Rewrite `org/main.tf`**

Replace the entire file with:

```hcl
resource "aws_organizations_organization" "this" {
  feature_set = "ALL"
}

resource "aws_organizations_organizational_unit" "personal" {
  name      = "personal"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "certs" {
  name      = "certs"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "projects" {
  name      = "projects"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "management" {
  name      = "management"
  parent_id = aws_organizations_organization.this.roots[0].id
}
```

- [ ] **Step 2: Rewrite `org/variables.tf`**

Replace the entire file with:

```hcl
variable "aws_region" {
  type        = string
  description = "AWS region for the provider (org-level resources are global, but a region is required)"
  default     = "us-east-1"
}
```

- [ ] **Step 3: Rewrite `org/outputs.tf`**

Replace the entire file with:

```hcl
output "root_id" {
  description = "ID of the organization root"
  value       = aws_organizations_organization.this.roots[0].id
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

output "management_ou_id" {
  description = "ID of the management/ OU"
  value       = aws_organizations_organizational_unit.management.id
}
```

- [ ] **Step 4: Validate**

```bash
cd providers/aws/org
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Plan to confirm no destructive changes to org/OUs**

```bash
terraform plan
```

Expected: 0 changes to `aws_organizations_organization` or `aws_organizations_organizational_unit` resources. Only account resources should be absent (they were state-removed in Task 1).

- [ ] **Step 6: Commit**

```bash
cd <repo root>
git add providers/aws/org/main.tf providers/aws/org/variables.tf providers/aws/org/outputs.tf
git commit -m "refactor(aws/org): manage OUs only — remove aws_organizations_account resources"
```

---

## Task 3: Enhance `modules/baseline/` with budgets

Add budget + SNS infrastructure to the baseline module so every account gets it automatically.

**Files:**
- Create: `providers/aws/modules/baseline/budgets.tf`
- Modify: `providers/aws/modules/baseline/variables.tf`
- Modify: `providers/aws/modules/baseline/outputs.tf`

- [ ] **Step 1: Create `modules/baseline/budgets.tf`**

```hcl
data "aws_caller_identity" "current" {}

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

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_budgets_budget" "this" {
  name              = "${var.account_name}-monthly"
  budget_type       = "COST"
  limit_amount      = tostring(var.budget_amount)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

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

- [ ] **Step 2: Add new variables to `modules/baseline/variables.tf`**

Append to the existing file (keep the three existing variables, add these three):

```hcl
variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD for this account"
  default     = 10
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds that trigger SNS alerts (e.g. [0.5, 0.9, 1.0] = 50%, 90%, 100%)"
  default     = [0.5, 0.9, 1.0]
}

variable "notification_email" {
  type        = string
  description = "Email address for budget alert SNS subscription"
}
```

- [ ] **Step 3: Update `modules/baseline/outputs.tf`**

Replace the entire file with:

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_actions.arn
}

output "account_id" {
  description = "AWS account ID this baseline is applied to"
  value       = data.aws_caller_identity.current.account_id
}

output "budget_alerts_sns_topic_arn" {
  description = "ARN of the SNS topic used for budget alerts"
  value       = aws_sns_topic.budget_alerts.arn
}
```

- [ ] **Step 4: Validate the module**

```bash
cd providers/aws/modules/baseline
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Commit**

```bash
cd <repo root>
git add providers/aws/modules/baseline/
git commit -m "feat(aws/modules/baseline): add budgets and SNS alert infrastructure"
```

---

## Task 4: Refactor `management/tapshalkar-com/`

Management is the most complex account — it uses the baseline module for OIDC + budget, then wires PagerDuty as an additional SNS subscriber.

**Files:**
- Modify: `providers/aws/accounts/management/tapshalkar-com/main.tf`
- Modify: `providers/aws/accounts/management/tapshalkar-com/notifications.tf`
- Modify: `providers/aws/accounts/management/tapshalkar-com/variables.tf`
- Modify: `providers/aws/accounts/management/tapshalkar-com/outputs.tf`
- Delete: `providers/aws/accounts/management/tapshalkar-com/oidc.tf`
- Delete: `providers/aws/accounts/management/tapshalkar-com/budgets.tf`

- [ ] **Step 1: Rewrite `management/tapshalkar-com/main.tf`**

```hcl
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

  account_name       = "tapshalkar-com"
  region             = var.aws_region
  github_repo        = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount      = var.budget_amount
  budget_thresholds  = var.budget_thresholds
  notification_email = var.notification_email
}
```

- [ ] **Step 2: Rewrite `management/tapshalkar-com/notifications.tf`**

Replace the entire file with (just the PagerDuty subscription — SNS topic now lives in baseline):

```hcl
resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn = module.baseline.budget_alerts_sns_topic_arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/${data.terraform_remote_state.pagerduty.outputs.integration_key}/enqueue"

  # PagerDuty auto-confirms HTTPS SNS subscriptions — no manual confirmation needed.
  endpoint_auto_confirms = true
}
```

- [ ] **Step 3: Rewrite `management/tapshalkar-com/variables.tf`**

```hcl
variable "aws_region" {
  type        = string
  description = "AWS region for management account resources (SNS topics are regional)"
  default     = "us-east-1"
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD for the management account"
  default     = 10
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds triggering SNS alerts (e.g. [0.5, 0.9, 1.0] = 50%, 90%, 100%)"
  default     = [0.5, 0.9, 1.0]
}

variable "notification_email" {
  type        = string
  description = "Email address for budget alert SNS subscription"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in 'owner/repo' format for OIDC trust policy."
}
```

- [ ] **Step 4: Rewrite `management/tapshalkar-com/outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (management account)"
  value       = module.baseline.github_actions_role_arn
}

output "account_id" {
  description = "AWS account ID of the management account"
  value       = module.baseline.account_id
}
```

- [ ] **Step 5: Delete `oidc.tf` and `budgets.tf`**

```bash
rm providers/aws/accounts/management/tapshalkar-com/oidc.tf
rm providers/aws/accounts/management/tapshalkar-com/budgets.tf
```

- [ ] **Step 6: Update `terraform.tfvars.example`**

Replace `providers/aws/accounts/management/tapshalkar-com/terraform.tfvars.example` with:

```hcl
aws_region         = "us-east-1"
budget_amount      = 10
budget_thresholds  = [0.5, 0.9, 1.0]
notification_email = "you@example.com"
github_repo        = "owner/core-infra"
```

- [ ] **Step 7: Validate**

```bash
cd providers/aws/accounts/management/tapshalkar-com
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 8: Commit**

```bash
cd <repo root>
git add providers/aws/accounts/management/tapshalkar-com/
git commit -m "refactor(aws/accounts/management): use baseline module for OIDC + budgets"
```

---

## Task 5: Update `personal/tapshalkar-com-personal/`

**Files:**
- Modify: `providers/aws/accounts/personal/tapshalkar-com-personal/main.tf`
- Modify: `providers/aws/accounts/personal/tapshalkar-com-personal/variables.tf`
- Modify: `providers/aws/accounts/personal/tapshalkar-com-personal/outputs.tf`

- [ ] **Step 1: Rewrite `main.tf`**

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

  account_name       = "tapshalkar-com-personal"
  region             = var.region
  github_repo        = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount      = var.budget_amount
  budget_thresholds  = var.budget_thresholds
  notification_email = var.notification_email
}
```

- [ ] **Step 2: Rewrite `variables.tf`**

```hcl
variable "account_id" {
  type        = string
  description = "AWS account ID of the tapshalkar-com-personal account (used for assume_role in versions.tf)"
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
  description = "Email address for budget alert SNS subscription"
}
```

- [ ] **Step 3: Rewrite `outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (tapshalkar-com-personal account)"
  value       = module.baseline.github_actions_role_arn
}

output "account_id" {
  description = "AWS account ID of the tapshalkar-com-personal account"
  value       = module.baseline.account_id
}
```

- [ ] **Step 4: Update `terraform.tfvars.example`**

```hcl
account_id         = "123456789012"
region             = "us-east-1"
budget_amount      = 10
budget_thresholds  = [0.5, 0.9, 1.0]
notification_email = "you@example.com"
```

- [ ] **Step 5: Validate**

```bash
cd providers/aws/accounts/personal/tapshalkar-com-personal
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Commit**

```bash
cd <repo root>
git add providers/aws/accounts/personal/tapshalkar-com-personal/
git commit -m "refactor(aws/accounts/personal): wire budget vars into tapshalkar-com-personal"
```

---

## Task 6: Update `personal/tapshalkar-com-sandbox/`

Identical pattern to Task 5 but for the sandbox account.

**Files:**
- Modify: `providers/aws/accounts/personal/tapshalkar-com-sandbox/main.tf`
- Modify: `providers/aws/accounts/personal/tapshalkar-com-sandbox/variables.tf`
- Modify: `providers/aws/accounts/personal/tapshalkar-com-sandbox/outputs.tf`

- [ ] **Step 1: Rewrite `main.tf`**

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

  account_name       = "tapshalkar-com-sandbox"
  region             = var.region
  github_repo        = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount      = var.budget_amount
  budget_thresholds  = var.budget_thresholds
  notification_email = var.notification_email
}
```

- [ ] **Step 2: Rewrite `variables.tf`**

```hcl
variable "account_id" {
  type        = string
  description = "AWS account ID of the tapshalkar-com-sandbox account (used for assume_role in versions.tf)"
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
  description = "Email address for budget alert SNS subscription"
}
```

- [ ] **Step 3: Rewrite `outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (tapshalkar-com-sandbox account)"
  value       = module.baseline.github_actions_role_arn
}

output "account_id" {
  description = "AWS account ID of the tapshalkar-com-sandbox account"
  value       = module.baseline.account_id
}
```

- [ ] **Step 4: Update `terraform.tfvars.example`**

```hcl
account_id         = "123456789012"
region             = "us-east-1"
budget_amount      = 10
budget_thresholds  = [0.5, 0.9, 1.0]
notification_email = "you@example.com"
```

- [ ] **Step 5: Validate**

```bash
cd providers/aws/accounts/personal/tapshalkar-com-sandbox
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Commit**

```bash
cd <repo root>
git add providers/aws/accounts/personal/tapshalkar-com-sandbox/
git commit -m "refactor(aws/accounts/personal): wire budget vars into tapshalkar-com-sandbox"
```

---

## Task 7: Update `certs/tapshalkar-com-certs/`

**Files:**
- Modify: `providers/aws/accounts/certs/tapshalkar-com-certs/main.tf`
- Modify: `providers/aws/accounts/certs/tapshalkar-com-certs/variables.tf`
- Modify: `providers/aws/accounts/certs/tapshalkar-com-certs/outputs.tf`

- [ ] **Step 1: Rewrite `main.tf`**

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

  account_name       = "tapshalkar-com-certs"
  region             = var.region
  github_repo        = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount      = var.budget_amount
  budget_thresholds  = var.budget_thresholds
  notification_email = var.notification_email
}
```

- [ ] **Step 2: Rewrite `variables.tf`**

```hcl
variable "account_id" {
  type        = string
  description = "AWS account ID of the tapshalkar-com-certs account (used for assume_role in versions.tf)"
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
  description = "Email address for budget alert SNS subscription"
}
```

- [ ] **Step 3: Rewrite `outputs.tf`**

```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (tapshalkar-com-certs account)"
  value       = module.baseline.github_actions_role_arn
}

output "account_id" {
  description = "AWS account ID of the tapshalkar-com-certs account"
  value       = module.baseline.account_id
}
```

- [ ] **Step 4: Update `terraform.tfvars.example`**

```hcl
account_id         = "123456789012"
region             = "us-east-1"
budget_amount      = 10
budget_thresholds  = [0.5, 0.9, 1.0]
notification_email = "you@example.com"
```

- [ ] **Step 5: Validate**

```bash
cd providers/aws/accounts/certs/tapshalkar-com-certs
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Commit**

```bash
cd <repo root>
git add providers/aws/accounts/certs/tapshalkar-com-certs/
git commit -m "refactor(aws/accounts/certs): wire budget vars into tapshalkar-com-certs"
```

---

## Task 8: Delete old account roots

**Files:**
- Delete: `providers/aws/accounts/personal/` (old standalone root — the 6 files directly in this dir, not the sub-dirs)
- Delete: `providers/aws/accounts/projects/` (entire folder)

Note: `certs/account-1/` and `certs/account-2/` are already deleted in the working tree (shown as `D` in git status) — they just need to be staged.

- [ ] **Step 1: Delete old standalone personal root files**

The old root is the files directly in `accounts/personal/` (not the `tapshalkar-com-*` subdirs):

```bash
git rm providers/aws/accounts/personal/main.tf
git rm providers/aws/accounts/personal/variables.tf
git rm providers/aws/accounts/personal/outputs.tf
git rm providers/aws/accounts/personal/backend.tf
git rm providers/aws/accounts/personal/versions.tf
git rm providers/aws/accounts/personal/terraform.tfvars.example
git rm providers/aws/accounts/personal/README.md
git rm providers/aws/accounts/personal/.terraform.lock.hcl
```

- [ ] **Step 2: Delete `projects/side-project/`**

```bash
git rm -r providers/aws/accounts/projects/
```

- [ ] **Step 3: Stage already-deleted certs accounts**

```bash
git rm -r providers/aws/accounts/certs/account-1/
git rm -r providers/aws/accounts/certs/account-2/
```

- [ ] **Step 4: Verify nothing unintended was removed**

```bash
git status providers/aws/accounts/
```

Expected: only deletions of the old roots — the `tapshalkar-com-*` directories should show as untracked or modified, not deleted.

- [ ] **Step 5: Commit**

```bash
git commit -m "chore(aws/accounts): remove retired account roots (personal standalone, certs/account-1, certs/account-2, projects/side-project)"
```

---

## Task 9: Rewrite `scripts/create-aws-account.sh`

The script currently patches `org/main.tf`, `org/variables.tf`, `org/outputs.tf`, and `management/tapshalkar-com/budgets.tf`. After this refactor none of those files need touching when a new account is added. The script should instead scaffold the account root with budget vars and provide AWS CLI commands for account creation.

**Files:**
- Modify: `scripts/create-aws-account.sh`

- [ ] **Step 1: Rewrite `create-aws-account.sh`**

Replace the entire file with:

```bash
#!/usr/bin/env bash
# Usage: ./scripts/create-aws-account.sh <ou> <account-name>
#
# Scaffolds a new AWS member account into the core-infra monorepo:
#   • Creates providers/aws/accounts/<ou>/<account-name>/ with all Terraform files
#   • Wires the account into providers/github/ with a new OIDC role ARN secret
#
# Account creation in AWS is done via the AWS CLI (see "Next steps" output).
# org/ Terraform is NOT modified — it manages OUs only.
#
# <ou>           OU to place the account in: certs | projects | personal | management
# <account-name> Slug for the account (lowercase, hyphens OK — e.g. "tapshalkar-com-dev")
#
# Example:
#   ./scripts/create-aws-account.sh personal tapshalkar-com-dev
#   ./scripts/create-aws-account.sh certs tapshalkar-com-certs-2

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALID_OUS=("certs" "projects" "personal" "management")
STATE_BUCKET="tapshalkar-com-tfstate"

# ── Validate args ──────────────────────────────────────────────────────────────
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <ou> <account-name>"
  echo "  ou:           one of: ${VALID_OUS[*]}"
  echo "  account-name: slug for the account (e.g. tapshalkar-com-dev)"
  exit 1
fi

OU="$1"
ACCOUNT_NAME="$2"
TARGET="$REPO_ROOT/providers/aws/accounts/$OU/$ACCOUNT_NAME"

if [[ ! " ${VALID_OUS[*]} " =~ " $OU " ]]; then
  echo "Error: OU must be one of: ${VALID_OUS[*]}"
  exit 1
fi

if [[ ! "$ACCOUNT_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: account-name must be lowercase alphanumeric with hyphens (e.g. tapshalkar-com-dev)"
  exit 1
fi

if [[ -d "$TARGET" ]]; then
  echo "Error: $TARGET already exists"
  exit 1
fi

RESOURCE_NAME="${ACCOUNT_NAME//-/_}"
SECRET_SUFFIX="$(echo "$RESOURCE_NAME" | tr '[:lower:]' '[:upper:]')"

echo "Scaffolding AWS account: $ACCOUNT_NAME"
echo "  OU:             $OU"
echo "  GitHub secret:  AWS_${SECRET_SUFFIX}_ROLE_ARN"
echo ""

# ── 1. Create account root directory ──────────────────────────────────────────
mkdir -p "$TARGET"

# versions.tf — assumes role into the member account via OrganizationAccountAccessRole
cat > "$TARGET/versions.tf" <<EOF
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
    role_arn = "arn:aws:iam::\${var.account_id}:role/OrganizationAccountAccessRole"
  }
}
EOF

# backend.tf
cat > "$TARGET/backend.tf" <<EOF
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/$OU/$ACCOUNT_NAME"
  }
}
EOF

# variables.tf
cat > "$TARGET/variables.tf" <<EOF
variable "account_id" {
  type        = string
  description = "AWS account ID of the $ACCOUNT_NAME account (used for assume_role in versions.tf)"
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
  description = "Email address for budget alert SNS subscription"
}
EOF

# main.tf
cat > "$TARGET/main.tf" <<EOF
data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "$STATE_BUCKET"
    prefix = "github"
  }
}

module "baseline" {
  source = "../../../modules/baseline"

  account_name       = "$ACCOUNT_NAME"
  region             = var.region
  github_repo        = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount      = var.budget_amount
  budget_thresholds  = var.budget_thresholds
  notification_email = var.notification_email
}
EOF

# outputs.tf
cat > "$TARGET/outputs.tf" <<EOF
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication ($ACCOUNT_NAME account)"
  value       = module.baseline.github_actions_role_arn
}

output "account_id" {
  description = "AWS account ID of the $ACCOUNT_NAME account"
  value       = module.baseline.account_id
}
EOF

# terraform.tfvars.example
cat > "$TARGET/terraform.tfvars.example" <<EOF
account_id         = "123456789012"
region             = "us-east-1"
budget_amount      = 10
budget_thresholds  = [0.5, 0.9, 1.0]
notification_email = "you@example.com"
EOF

# README.md
cat > "$TARGET/README.md" <<EOF
# \`$OU/$ACCOUNT_NAME\`

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
EOF

echo "✓ Account root files written to providers/aws/accounts/$OU/$ACCOUNT_NAME/"

# ── 2. Patch providers/github/main.tf ─────────────────────────────────────────
GITHUB_MAIN="$REPO_ROOT/providers/github/main.tf"

python3 - "$GITHUB_MAIN" "$RESOURCE_NAME" "$OU" "$ACCOUNT_NAME" "$STATE_BUCKET" <<'PYEOF'
import sys, re

path, resource_name, ou, account_name, state_bucket = \
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
content = open(path).read()
backend_prefix = f"aws/accounts/{ou}/{account_name}"

new_state_block = f'''
data "terraform_remote_state" "aws_{resource_name}" {{
  backend = "gcs"
  config = {{
    bucket = "{state_bucket}"
    prefix = "{backend_prefix}"
  }}
}}
'''

new_secret_block = f'''
resource "github_actions_secret" "aws_{resource_name}_role_arn" {{
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_{resource_name.upper()}_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_{resource_name}.outputs.github_actions_role_arn
}}
'''

changed = False

if f'data "terraform_remote_state" "aws_{resource_name}"' not in content:
    content = re.sub(
        r'(# ── AWS Actions secrets ─+)',
        new_state_block.rstrip('\n') + '\n\n' + r'\1',
        content,
        count=1
    )
    changed = True
    print(f"✓ Added aws_{resource_name} remote state to github/main.tf")
else:
    print(f"⚠ aws_{resource_name} remote state already present — skipping")

if f'resource "github_actions_secret" "aws_{resource_name}_role_arn"' not in content:
    if '# ── AWS Actions variables' in content:
        content = re.sub(
            r'(# ── AWS Actions variables ─+)',
            new_secret_block.rstrip('\n') + '\n\n' + r'\1',
            content,
            count=1
        )
    else:
        content = content.rstrip('\n') + '\n' + new_secret_block
    changed = True
    print(f"✓ Added aws_{resource_name}_role_arn secret to github/main.tf")
else:
    print(f"⚠ aws_{resource_name}_role_arn already present — skipping")

if changed:
    open(path, 'w').write(content)
PYEOF

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "✓ '$ACCOUNT_NAME' scaffolded. Files changed:"
echo "  + providers/aws/accounts/$OU/$ACCOUNT_NAME/  (new)"
echo "  ~ providers/github/main.tf"
echo ""
echo "Next steps:"
echo ""
echo "  1. Create the AWS account via CLI (from a session with management account credentials):"
echo "     aws organizations create-account \\"
echo "       --account-name \"<display name>\" \\"
echo "       --email \"<root-email>\" \\"
echo "       --iam-user-access-to-billing ALLOW"
echo ""
echo "     Then move it to the correct OU:"
echo "     aws organizations move-account \\"
echo "       --account-id <NEW_ACCOUNT_ID> \\"
echo "       --source-parent-id <ROOT_ID> \\"
echo "       --destination-parent-id <${OU^^}_OU_ID>"
echo ""
echo "     OU IDs are in: cd providers/aws/org && terraform output"
echo ""
echo "  2. Create account tfvars from example (use the account ID from step 1):"
echo "     cp $TARGET/terraform.tfvars.example $TARGET/terraform.tfvars"
echo "     \$EDITOR $TARGET/terraform.tfvars"
echo ""
echo "  3. Apply the account root (sets up OIDC + budget):"
echo "     cd $TARGET"
echo "     terraform init -backend-config=\"bucket=$STATE_BUCKET\""
echo "     terraform plan && terraform apply"
echo ""
echo "  4. Apply providers/github/ to publish AWS_${SECRET_SUFFIX}_ROLE_ARN to GitHub Actions:"
echo "     cd $REPO_ROOT/providers/github"
echo "     terraform plan && terraform apply"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/create-aws-account.sh
```

- [ ] **Step 3: Dry-run the script against a test account name (no AWS calls, just file scaffold)**

```bash
./scripts/create-aws-account.sh personal tapshalkar-com-test 2>&1 | head -20
ls providers/aws/accounts/personal/tapshalkar-com-test/
```

Expected: directory created with `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`, `versions.tf`, `terraform.tfvars.example`, `README.md`.

- [ ] **Step 4: Validate the scaffolded test account**

```bash
cd providers/aws/accounts/personal/tapshalkar-com-test
terraform init -backend="false"
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Remove the test scaffold**

```bash
cd <repo root>
rm -rf providers/aws/accounts/personal/tapshalkar-com-test
```

- [ ] **Step 6: Commit**

```bash
git add scripts/create-aws-account.sh
git commit -m "refactor(scripts): rewrite create-aws-account.sh — remove org patching, add budget vars to scaffold"
```

---

## Apply Order (post-implementation)

Run these in order when applying to real AWS:

```
1. providers/aws/org/               — verify plan shows 0 OU changes
2. providers/aws/accounts/management/tapshalkar-com/  — new baseline + PagerDuty wiring
3. providers/aws/accounts/personal/tapshalkar-com-personal/
4. providers/aws/accounts/personal/tapshalkar-com-sandbox/
5. providers/aws/accounts/certs/tapshalkar-com-certs/
6. providers/github/                — publishes updated role ARNs
```
