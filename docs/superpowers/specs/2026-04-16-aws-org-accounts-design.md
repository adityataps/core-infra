# AWS Organization + Accounts Design

> Supersedes: `2026-04-15-aws-org-baseline-design.md`

## Goal

Bring a pre-existing AWS Organization (1 management account, 2 certs accounts, 1 side-project account) under Terraform management in this repo. Create a GCP-style hierarchy using OUs, add a new dedicated personal member account, and wire GitHub Actions authentication for every account via OIDC. Centralize all billing alerts on the management account.

## Current State

- AWS Organization already exists and is enabled
- Management account = org root (also currently used for personal workloads — will be repurposed to org-admin only over time)
- 2 certs member accounts — already in org, need to be imported
- 1 side-project member account — already in org, needs to be imported
- No personal member account yet — created fresh
- Existing budgets on member accounts will be replaced by centralized management-account budgets

## Architecture

### Org Hierarchy

```
Root
└── management account          ← always at root; cannot be placed in an OU
    ├── personal/  (OU)
    │   └── personal member account  (new, greenfield)
    ├── certs/  (OU)
    │   ├── certs-account-1  (imported)
    │   └── certs-account-2  (imported)
    └── projects/  (OU)
        └── side-project  (imported)
```

### Billing / Budget Centralization

The management account acts as billing authority. All `aws_budgets_budget` resources live there, each filtered to a single linked account via `filter { linked_accounts = [account_id] }`. A single SNS topic receives all budget threshold notifications; a single PagerDuty HTTPS subscription on that topic covers every account. No budget or SNS resources exist in member account roots.

### GitHub Actions Authentication

Each account (management and all members) gets an OIDC provider and an IAM role scoped to `var.github_repo`. The management account sets this up directly in its own root (not via the shared module, since it uses default credentials). Member accounts use the shared baseline module.

## Directory Structure

```
providers/
└── aws/
    ├── org/                              — OUs + member account assignments
    │   ├── versions.tf                   — aws provider; GCS backend prefix: "aws/org"
    │   ├── backend.tf
    │   ├── variables.tf                  — aws_region
    │   ├── main.tf                       — data org, OUs, aws_organizations_account resources
    │   └── outputs.tf                    — root_id, OU IDs, all member account IDs
    │
    ├── modules/
    │   └── baseline/                     — reusable per-member-account module (OIDC only)
    │       ├── versions.tf
    │       ├── variables.tf              — account_name, region, github_repo
    │       ├── oidc.tf                   — OIDC provider + IAM role for GitHub Actions
    │       └── outputs.tf                — github_actions_role_arn
    │
    └── accounts/
        ├── management/                   — billing authority: budgets + SNS + PagerDuty + OIDC
        │   ├── versions.tf               — aws provider (default creds); GCS backend prefix: "aws/accounts/management"
        │   ├── backend.tf
        │   ├── variables.tf              — budget_amounts (map), budget_thresholds, github_repo
        │   ├── main.tf                   — remote state wiring (pagerduty, aws/org)
        │   ├── notifications.tf          — SNS topic + PagerDuty HTTPS subscription
        │   ├── budgets.tf                — one aws_budgets_budget per linked account
        │   ├── oidc.tf                   — OIDC provider + IAM role (covers all management-account GHA jobs)
        │   └── outputs.tf                — github_actions_role_arn
        │
        ├── personal/                     — new personal member account (greenfield)
        │   ├── versions.tf               — assume_role to personal account ID
        │   ├── backend.tf                — prefix: "aws/accounts/personal"
        │   ├── variables.tf
        │   ├── main.tf                   — module.baseline call
        │   └── outputs.tf                — github_actions_role_arn
        │
        ├── certs/
        │   ├── account-1/                — imported; same structure as personal/
        │   └── account-2/
        │
        └── projects/
            └── side-project/             — imported; same structure as personal/
```

## Resources Per Root

### `providers/aws/org/`

| Resource | Purpose |
|---|---|
| `data.aws_organizations_organization` | Looks up existing org; provides `roots[0].id` |
| `aws_organizations_organizational_unit` | Creates `personal/`, `certs/`, `projects/` OUs under root |
| `aws_organizations_account` | Manages member accounts: personal (new), certs x2 (imported), side-project x1 (imported) |

**Outputs:** `root_id`, `personal_ou_id`, `certs_ou_id`, `projects_ou_id`, `personal_account_id`, `certs_account_1_id`, `certs_account_2_id`, `side_project_account_id`

### `providers/aws/modules/baseline/`

| Resource | Purpose |
|---|---|
| `aws_iam_openid_connect_provider` | OIDC provider for `token.actions.githubusercontent.com` |
| `aws_iam_role` | IAM role with OIDC trust policy scoped to `var.github_repo`; permissions to run terraform for this account |

**Variables:** `account_name`, `region` (default `us-east-1`), `github_repo`

**Outputs:** `github_actions_role_arn`

### `providers/aws/accounts/management/`

| Resource | Purpose |
|---|---|
| `data.terraform_remote_state.pagerduty` | Reads `integration_key` from GCS prefix `pagerduty` |
| `data.terraform_remote_state.aws_org` | Reads all member account IDs from GCS prefix `aws/org` |
| `aws_sns_topic` | Shared notification topic for all budget alerts |
| `aws_sns_topic_subscription` | PagerDuty HTTPS endpoint (from pagerduty remote state) |
| `aws_sns_topic_policy` | Allows AWS Budgets service to publish to the topic |
| `aws_budgets_budget` (×4) | One per member account, filtered by `linked_accounts`; `budget_amounts` is a map keyed by account logical name |
| `aws_iam_openid_connect_provider` | GitHub OIDC (management account only) |
| `aws_iam_role` | IAM role for all management-account GHA jobs (`aws/org`, `aws/accounts/management`) |

**Variables:** `budget_amounts` (map of `account_name → number`), `budget_thresholds` (list, default `[0.5, 0.9, 1.0]`), `github_repo`

**Outputs:** `github_actions_role_arn`

### `providers/aws/accounts/<name>/`

Standard wrapper pattern (mirrors GCP project roots):

```hcl
provider "aws" {
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/OrganizationAccountAccessRole"
  }
}

data "terraform_remote_state" "aws_org" { ... }

module "baseline" {
  source      = "../../../modules/baseline"
  account_name = var.account_name
  region       = var.region
  github_repo  = var.github_repo
}
```

Backend prefix: `aws/accounts/<folder>/<name>` (e.g. `aws/accounts/certs/account-1`)

### `providers/github/` (extension)

Add `data.terraform_remote_state` blocks for each AWS account root, then add:

```hcl
resource "github_actions_secret" "aws_management_role_arn" { ... }
resource "github_actions_secret" "aws_personal_role_arn"   { ... }
resource "github_actions_secret" "aws_certs_1_role_arn"    { ... }
resource "github_actions_secret" "aws_certs_2_role_arn"    { ... }
resource "github_actions_secret" "aws_side_project_role_arn" { ... }
resource "github_actions_variable" "aws_region"            { ... }  # plaintext
```

Secret naming convention: `AWS_<ACCOUNT_NAME>_ROLE_ARN` (e.g. `AWS_PERSONAL_ROLE_ARN`)

## State Wiring + Apply Order

```
providers/pagerduty/                   prefix: pagerduty           (already live)
        ↓ remote_state
providers/aws/org/                     prefix: aws/org
        ↓ remote_state
providers/aws/accounts/management/     prefix: aws/accounts/management
providers/aws/accounts/personal/       prefix: aws/accounts/personal
providers/aws/accounts/certs/account-1/ ...
providers/aws/accounts/certs/account-2/ ...
providers/aws/accounts/projects/side-project/ ...
        ↓ remote_state
providers/github/                      prefix: github              (apply last)
```

**Apply order:**
1. `providers/pagerduty/` — already live, no change
2. `providers/aws/org/` — creates OUs, imports + places existing accounts
3. `providers/aws/accounts/management/` — budgets, SNS, PagerDuty, OIDC
4. `providers/aws/accounts/personal/` — greenfield, no imports
5. `providers/aws/accounts/certs/account-{1,2}/` — OIDC only (budgets are on management)
6. `providers/aws/accounts/projects/side-project/` — OIDC only
7. `providers/github/` — reads all remote states, writes all AWS secrets

## Import Sequence

### `providers/aws/org/`

```bash
# OUs — only if already exist; otherwise Terraform creates them
terraform import aws_organizations_organizational_unit.personal <OU_ID>
terraform import aws_organizations_organizational_unit.certs    <OU_ID>
terraform import aws_organizations_organizational_unit.projects <OU_ID>

# Member accounts (management account is a data source, not imported)
terraform import aws_organizations_account.certs_1      <ACCOUNT_ID>
terraform import aws_organizations_account.certs_2      <ACCOUNT_ID>
terraform import aws_organizations_account.side_project <ACCOUNT_ID>
# personal → created fresh via terraform apply
```

### `providers/aws/accounts/management/`

```bash
# Budgets — existing per-account budgets on member accounts can be deleted manually;
# management-account budgets are created fresh by Terraform (no import needed)
# OIDC — created fresh
```

### Member account roots

```bash
# No imports needed — OIDC resources are greenfield
# If OrganizationAccountAccessRole doesn't exist in a member account,
# it must be created manually or via the org's SCP before assume_role works
```

## Out of Scope

- AWS Service Control Policies (SCPs)
- AWS CloudTrail org-level logging
- AWS Config
- Migrating personal workloads off the management account (done manually over time)
- GitHub Actions workflow matrix updates for AWS roots (added separately)
