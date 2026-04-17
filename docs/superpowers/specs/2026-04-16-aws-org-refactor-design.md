# AWS Org/Accounts Refactor — Design Spec
**Date:** 2026-04-16

## Goal

Refactor the AWS provider structure to mirror the GCP pattern: `org/` manages organizational structure only, and each account root is fully self-contained and independently deployable. Account creation moves out of Terraform entirely (handled by `scripts/create-aws-account.sh`).

---

## Directory Structure

```
providers/aws/
├── org/                            # OUs only — no aws_organizations_account resources
├── modules/
│   └── baseline/                   # OIDC + GitHub Actions role + budgets
└── accounts/
    ├── management/
    │   └── tapshalkar-com/         # baseline + PagerDuty SNS subscription
    ├── personal/
    │   ├── tapshalkar-com-personal/
    │   └── tapshalkar-com-sandbox/
    └── certs/
        └── tapshalkar-com-certs/
```

### Removed

- `accounts/personal/` (old standalone root)
- `accounts/certs/account-1/`
- `accounts/certs/account-2/`
- `accounts/projects/` (entire folder, including `side-project/`)

---

## Section 1: `org/`

**Responsibility:** AWS Organization structure only — the OU hierarchy.

### What stays
- `aws_organizations_organization.this`
- All four `aws_organizations_organizational_unit` resources: `personal`, `certs`, `management`, `projects`

### What is removed
- All `aws_organizations_account.*` resources (personal, certs_1, certs_2, side_project, tapshalkar_com, tapshalkar_com_personal, tapshalkar_com_sandbox, tapshalkar_com_certs)
- All per-account variables (`*_account_name`, `*_account_email`)
- All account ID outputs

### `variables.tf` after refactor
```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
```

### `outputs.tf` after refactor
```hcl
output "root_id"         { value = aws_organizations_organization.this.roots[0].id }
output "personal_ou_id"  { value = aws_organizations_organizational_unit.personal.id }
output "certs_ou_id"     { value = aws_organizations_organizational_unit.certs.id }
output "management_ou_id"{ value = aws_organizations_organizational_unit.management.id }
output "projects_ou_id"  { value = aws_organizations_organizational_unit.projects.id }
```

### State migration
Before applying, remove old account resources from state to avoid Terraform attempting to close live AWS accounts:
```bash
cd providers/aws/org
terraform state rm aws_organizations_account.personal
terraform state rm aws_organizations_account.certs_1
terraform state rm aws_organizations_account.certs_2
terraform state rm aws_organizations_account.side_project
terraform state rm aws_organizations_account.tapshalkar_com
terraform state rm aws_organizations_account.tapshalkar_com_personal
terraform state rm aws_organizations_account.tapshalkar_com_sandbox
terraform state rm aws_organizations_account.tapshalkar_com_certs
```

---

## Section 2: `modules/baseline/`

**Responsibility:** All per-account defaults — OIDC federation, GitHub Actions IAM role, budget alert infrastructure. Mirrors GCP's `modules/baseline/` which includes budgets in the module.

### New file: `budgets.tf`
```hcl
data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "budget_alerts" {
  name = "budget-alerts"
}

resource "aws_sns_topic_policy" "budget_alerts" {
  arn    = aws_sns_topic.budget_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowBudgetsToPublish"
      Effect    = "Allow"
      Principal = { Service = "budgets.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.budget_alerts.arn
    }]
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

### New variables (added to `variables.tf`)
```hcl
variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD"
  default     = 10
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds for alerts (e.g. [0.5, 0.9, 1.0])"
  default     = [0.5, 0.9, 1.0]
}

variable "notification_email" {
  type        = string
  description = "Email address for budget alert SNS subscription"
}
```

### New outputs (added to `outputs.tf`)
```hcl
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "budget_alerts_sns_topic_arn" {
  value = aws_sns_topic.budget_alerts.arn
}
```

---

## Section 3: Account Roots — Uniform Pattern

Every account root follows the same structure. Backend prefix: `aws/accounts/<folder>/<name>`.

### `main.tf` (all non-management accounts)
```hcl
data "terraform_remote_state" "github" {
  backend = "gcs"
  config  = { bucket = "tapshalkar-com-tfstate", prefix = "github" }
}

module "baseline" {
  source             = "../../../modules/baseline"
  account_name       = "<account-name>"
  region             = var.region
  github_repo        = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount      = var.budget_amount
  budget_thresholds  = var.budget_thresholds
  notification_email = var.notification_email
}
```

### `main.tf` (management account — `tapshalkar-com`)
Same as above, plus reads PagerDuty remote state. `notifications.tf` is retained for the PagerDuty HTTPS subscription only:

```hcl
# notifications.tf — management account only
data "terraform_remote_state" "pagerduty" {
  backend = "gcs"
  config  = { bucket = "tapshalkar-com-tfstate", prefix = "pagerduty" }
}

resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn              = module.baseline.budget_alerts_sns_topic_arn
  protocol               = "https"
  endpoint               = "https://events.pagerduty.com/integration/${data.terraform_remote_state.pagerduty.outputs.integration_key}/enqueue"
  endpoint_auto_confirms = true
}
```

The standalone `oidc.tf` and `budgets.tf` in `management/tapshalkar-com/` are removed — both are now provided by the baseline module.

### Account roots and their `budget_amount`
| Account | Folder | Budget |
|---|---|---|
| tapshalkar-com | management | 10 |
| tapshalkar-com-personal | personal | 10 |
| tapshalkar-com-sandbox | personal | 10 |
| tapshalkar-com-certs | certs | 10 |

---

## Section 4: `scripts/create-aws-account.sh`

Update the script to reflect that `org/` no longer manages account resources. The script remains the sole mechanism for account creation. It should:

1. Create the account via AWS Organizations CLI (`aws organizations create-account`)
2. Move it to the correct OU (`aws organizations move-account`)
3. Scaffold the new account root directory under `accounts/<folder>/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`, `versions.tf`, `terraform.tfvars.example`

No changes to `org/` Terraform are required when adding a new account.

---

## Apply Order

1. `terraform state rm` old accounts from `org/` state
2. Apply `providers/aws/org/` (removes account resources from config, applies OU-only state)
3. Apply `providers/aws/accounts/management/tapshalkar-com/` (baseline now includes budgets)
4. Apply each remaining account root in any order

---

## Key Decisions

| Decision | Rationale |
|---|---|
| Account creation via script, not Terraform | Mirrors GCP pattern; accounts are self-managing. `aws_organizations_account` requires management-account context which breaks independence. |
| Budgets in baseline module | Mirrors GCP's `modules/baseline/budgets.tf`; each account owns its own budget, no cross-account coupling. |
| PagerDuty subscription stays in management only | PagerDuty is a management-level concern. Other accounts use email-only alerts via baseline. |
| `org/` outputs only OU IDs | Account roots don't need OU IDs at runtime — OU placement is a one-time creation concern handled by the script. |
