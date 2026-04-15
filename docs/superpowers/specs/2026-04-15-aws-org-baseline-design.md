# AWS Organization + Per-Account Baseline Design

## Goal

Establish a multi-account AWS organization hierarchy under a dedicated management account, with reusable per-account baseline module (budgets, PagerDuty via SNS, CloudWatch, GitHub OIDC), and a shared GitHub provider root that automates all GHA secret management across GCP and AWS.

## Architecture

A new `providers/aws/org/` root manages the organization structure: OUs and account membership. Each account instantiates a reusable `providers/aws/modules/baseline/` module. A shared `providers/github/` root reads outputs from all account and project remote states and writes them directly to GitHub Actions secrets — eliminating all manual copy-paste.

The existing management account (currently also the personal account) is repurposed as org-admin only. A new personal member account is created for personal workloads. Existing cert and project accounts are imported and moved into their respective OUs.

## Directory Structure

```
providers/
├── aws/
│   ├── org/                        — OUs + account membership
│   │   ├── versions.tf             — aws provider, GCS backend (prefix: "aws/org")
│   │   ├── backend.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   └── outputs.tf              — OU IDs, account IDs
│   │
│   ├── modules/baseline/           — reusable per-account module
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── budgets.tf              — aws_budgets_budget → SNS
│   │   ├── monitoring.tf           — CloudWatch stub alarm → SNS
│   │   ├── notifications.tf        — SNS topic + PagerDuty HTTPS subscription
│   │   ├── oidc.tf                 — GitHub Actions OIDC provider + IAM role
│   │   └── outputs.tf              — github_actions_role_arn
│   │
│   └── accounts/
│       ├── management/             — management account (org-level resources only)
│       ├── personal/               — new personal member account (greenfield)
│       ├── certs/
│       │   ├── account-1/          — existing cert accounts (imported)
│       │   └── account-2/
│       └── projects/
│           └── account-1/          — existing project account (imported)
│
└── github/                         — shared GitHub provider root
    ├── versions.tf                 — github + terraform providers, GCS backend (prefix: "github")
    ├── backend.tf
    ├── variables.tf                — github_token, github_repo
    ├── main.tf                     — reads all remote states, sets all GHA secrets
    └── terraform.tfvars.example
```

## Resources Per Root

### `providers/aws/org/`

- `data.aws_organizations_organization` — looks up existing org (no import needed)
- `aws_organizations_organizational_unit` — `personal/`, `certs/`, `projects/` OUs under root
- `aws_organizations_account` — new personal member account (greenfield); existing cert + project accounts imported and moved into OUs via `parent_id`

**Outputs:** `root_id`, `personal_ou_id`, `certs_ou_id`, `projects_ou_id`, all account IDs

### `providers/aws/modules/baseline/`

- `notifications.tf` — `aws_sns_topic` + `aws_sns_topic_subscription` (PagerDuty HTTPS endpoint) + `aws_sns_topic_policy`
- `budgets.tf` — `aws_budgets_budget` with SNS notification, `budget_amount` + `budget_thresholds` variables (mirrors GCP pattern)
- `monitoring.tf` — `aws_cloudwatch_metric_alarm` stub (disabled by default, mirrors GCP alert policy stub)
- `oidc.tf` — `aws_iam_openid_connect_provider` for `token.actions.githubusercontent.com` + `aws_iam_role` with OIDC trust policy scoped to `var.github_repo`

**Variables:** `account_name`, `region`, `budget_amount`, `budget_thresholds` (default `[0.5, 0.9, 1.0]`), `pagerduty_integration_key` (sensitive), `github_repo` (optional, `default = null`)

**Outputs:** `github_actions_role_arn`

### `providers/aws/accounts/<name>/`

Each account root follows the same pattern:

- `data.terraform_remote_state.pagerduty` — reads `integration_key` from GCS prefix `pagerduty`
- `module.baseline` — instantiates baseline with account-specific vars
- Provider configured with `assume_role` to the target member account (except management, which uses default credentials)
- `backend.tf` prefix: `aws/accounts/<folder>/<name>` (e.g. `aws/accounts/certs/account-1`)

### `providers/github/`

- `data.terraform_remote_state` blocks — one per GCP project and AWS account
- `github_actions_secret` — sets per-account GHA secrets:
  - GCP: `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT` (retroactively automates current manual step)
  - AWS per-account: `AWS_<ACCOUNT_NAME>_ROLE_ARN`
- `github_actions_variable` — `AWS_<ACCOUNT_NAME>_REGION` (plaintext)

**Variables:** `github_token` (sensitive), `github_repo`

## State Wiring + Apply Order

```
providers/pagerduty/               prefix: pagerduty          (already live)
        ↓ remote_state
providers/aws/org/                 prefix: aws/org
        ↓ remote_state
providers/aws/accounts/*/          prefix: aws/accounts/<folder>/<name>
        ↓ remote_state
providers/gcp/org/                 prefix: gcp/org
        ↓ remote_state
providers/gcp/projects/*/          prefix: gcp/projects/<folder>/<name>
        ↓ remote_state
providers/github/                  prefix: github
```

**Apply order:**
1. `providers/pagerduty/` — already live, no change
2. `providers/aws/org/` — creates OUs, imports + moves existing accounts
3. `providers/aws/accounts/*` — one apply per account (any order, independent)
4. `providers/gcp/org/` — creates GCP folders
5. `providers/gcp/projects/personal/adits-gcp/` — moves project under folder
6. `providers/github/` — reads all outputs, writes all GHA secrets (always apply last)

## Cascade Apply Script

`scripts/apply-all.sh` runs the full apply chain in dependency order:

- Runs `terraform init` + `terraform apply` per root in the order above
- Stops on any failure (set -e)
- Accepts `--auto-approve` flag (passed through to terraform)
- Accepts `--from <root-name>` flag to resume from a specific step (e.g. `--from aws/org`)
- Passes `-backend-config="bucket=adits-gcp-core-infra-tfstate"` to all `terraform init` calls

## Import Sequence

### `providers/aws/org/`

```bash
# Import existing org
terraform import aws_organizations_organization.this <ORG_ID>

# Import existing cert + project accounts (moved into OUs via parent_id in config)
terraform import aws_organizations_account.certs_1 <ACCOUNT_ID>
terraform import aws_organizations_account.certs_2 <ACCOUNT_ID>
terraform import aws_organizations_account.project_1 <ACCOUNT_ID>

# New personal member account → created fresh via terraform apply
```

### `providers/aws/accounts/management/`

```bash
# Uses default provider credentials — no account import needed
# Import existing budget if one exists:
terraform import aws_budgets_budget.main <ACCOUNT_ID>:<BUDGET_NAME>
```

### `providers/aws/accounts/certs/` + `accounts/projects/`

```bash
# Each uses assume_role provider targeting the member account ID
# Import existing budgets if present:
terraform import aws_budgets_budget.main <ACCOUNT_ID>:<BUDGET_NAME>
```

### `providers/github/`

Greenfield — `terraform apply` creates all secrets fresh. Existing manually-set secrets are overwritten with the same values sourced from Terraform outputs.

## Out of Scope

- AWS Service Control Policies (SCPs) — added later
- AWS CloudTrail org-level logging — added later
- AWS Config — added later
- Workload migration from management account to personal member account (done manually over time)
