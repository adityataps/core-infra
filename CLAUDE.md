# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform monorepo managing personal cloud infrastructure across GCP, AWS, and other providers. Each provider lives under `providers/` and is independently deployable with its own remote state. The `bootstrap/` directory creates the shared GCS remote state bucket and is run once.

## Common Commands

> Run all Terraform commands from within a specific directory (e.g. `bootstrap/` or `providers/gcp/projects/my-project/`) — there is no root-level Terraform configuration.

```bash
# Initialize Terraform (required before plan/apply)
terraform init

# Preview infrastructure changes
terraform plan

# Apply infrastructure changes
terraform apply

# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Destroy infrastructure (destructive — confirm with user first)
terraform destroy
```

## Key Conventions

- `.tfvars` and `.tfvars.json` files are gitignored — they contain secrets. Use the committed `terraform.tfvars.example` in each provider as a template.
- `backend.hcl` files are **committed** in every workspace — they contain only the state bucket name (`tapshalkar-com-tfstate`), which is not sensitive. Run `terraform init -backend-config=backend.hcl` after cloning.
- `override.tf` / `*_override.tf` files are also gitignored — they are used for local overrides only.
- State files (`*.tfstate`, `*.tfstate.*`) are excluded from version control; remote state backends (e.g., S3, GCS, Terraform Cloud) should be configured for shared use.

## Structure

- `bootstrap/` — creates the GCS remote state bucket (run once, local state).
- `providers/gcp/org/` — GCP organization root: `management/`, `personal/`, and `certs/` folders + org IAM. Apply before projects.
- `providers/gcp/modules/baseline/` — reusable module configuring GCP project defaults.
- `providers/gcp/projects/management/` — management/infra projects (TF state, WIF, billing). `tapshalkar-com` lives here.
- `providers/gcp/projects/<folder>/<name>/` — per-project instantiation of the baseline module, grouped by folder (`personal/`, `certs/`).
- `providers/cloudflare/` — Cloudflare DNS zones. `zones.tf` is the single source of truth for all domains; `modules/zone/` is the reusable per-zone module.
- `providers/pagerduty/` — PagerDuty service + integration. Apply before GCP projects.
- `providers/aws/` — AWS infrastructure (future, same pattern).
- `scripts/` — helper scripts for import, init, etc.

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
cd providers/gcp/projects/<folder>/my-project
terraform import module.baseline.google_project.this projects/<PROJECT_ID>
```

If the billing account is already linked and IAM bindings exist, import them too — check `terraform plan` output and run `terraform import` for any resource showing unexpected diffs.

## Adding a New GCP Project

1. `cp -r providers/gcp/projects/management/tapshalkar-com providers/gcp/projects/<folder>/<new-name>`
2. Update `backend.tf` prefix to `gcp/projects/<folder>/<new-name>`
3. Fill in a new `terraform.tfvars`
4. `terraform init -backend-config="bucket=<YOUR_STATE_BUCKET_NAME>"`
5. `terraform import module.baseline.google_project.this projects/<NEW_PROJECT_ID>`
6. `terraform plan && terraform apply`

## GitHub Actions Secrets

Two repository secrets must be set in GitHub (Settings → Secrets and variables → Actions):

- `GCP_WORKLOAD_IDENTITY_PROVIDER` — full WIF provider resource name, output from `terraform output workload_identity_provider` in the project dir
- `GCP_SERVICE_ACCOUNT` — service account email, output from `terraform output github_actions_service_account_email`

These are populated after the first `terraform apply` of the GCP baseline.

## PagerDuty Integration

The PagerDuty root (`providers/pagerduty/`) is applied independently from GCP. The integration key is read automatically via `terraform_remote_state` — no manual copy-paste required. Apply PagerDuty first, then GCP.

### First-time setup

1. Get the existing escalation policy ID from PagerDuty (Settings → Escalation Policies → click the policy → copy the ID from the URL: `/escalation_policies/<ID>`)
2. Fill in `providers/pagerduty/terraform.tfvars` (gitignored):
   ```hcl
   api_token      = "your-pagerduty-api-token"
   admin_email    = "you@example.com"
   gcp_project_id = "your-gcp-project-id"
   ```
3. Initialize and import the existing escalation policy:
   ```bash
   cd providers/pagerduty
   terraform init -backend-config="bucket=<YOUR_STATE_BUCKET_NAME>"
   terraform import pagerduty_escalation_policy.default <ESCALATION_POLICY_ID>
   ```
4. Update the `pagerduty_escalation_policy.default` resource block in `providers/pagerduty/main.tf` to match the imported state (run `terraform show` after import to see current values)
5. Apply PagerDuty:
   ```bash
   terraform apply
   ```
6. Apply the GCP project — it reads the integration key automatically from PagerDuty state:
   ```bash
   cd providers/gcp/projects/management/tapshalkar-com
   terraform apply
   ```

### Adding PagerDuty to another GCP project

Point the new project's `main.tf` at the same `terraform_remote_state.pagerduty` data source — the same PagerDuty service handles all GCP projects.

## Cloudflare DNS

All zones are managed from a single root at `providers/cloudflare/`. `zones.tf` is the single source of truth — one entry per domain. The `modules/zone/` module owns the `cloudflare_zone` resource and all DNS record types (A, MX, CNAME, TXT, SRV).

### First-time setup

1. Copy the example vars and fill in real values:
   ```bash
   cp providers/cloudflare/terraform.tfvars.example providers/cloudflare/terraform.tfvars
   # edit terraform.tfvars: api_token, account_id
   ```
   API token scopes required: **Zone:Zone:Edit** + **Zone:DNS:Edit**.
   Account ID is visible in the Cloudflare dashboard sidebar.

2. Initialize:
   ```bash
   cd providers/cloudflare
   terraform init -backend-config=backend.hcl
   ```

3. Import the zone (get the zone ID from the Cloudflare dashboard sidebar):
   ```bash
   terraform import 'module.zones["example.com"].cloudflare_zone.this' <ZONE_ID>
   ```

4. Import existing DNS records — one command per record:
   ```bash
   # A record:   key = "name:content"
   terraform import 'module.zones["example.com"].cloudflare_dns_record.a["@:1.2.3.4"]' '<ZONE_ID>/<RECORD_ID>'
   # MX record:  key = "name:content"
   terraform import 'module.zones["example.com"].cloudflare_dns_record.mx["@:smtp.google.com"]' '<ZONE_ID>/<RECORD_ID>'
   # CNAME:      key = "name" (no content)
   terraform import 'module.zones["example.com"].cloudflare_dns_record.cname["www"]' '<ZONE_ID>/<RECORD_ID>'
   # TXT:        key = "name:content" (content without outer quotes)
   terraform import 'module.zones["example.com"].cloudflare_dns_record.txt["@:v=spf1 include:_spf.google.com ~all"]' '<ZONE_ID>/<RECORD_ID>'
   ```
   Record IDs are available via the Cloudflare API:
   ```bash
   curl "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/dns_records" \
     -H "Authorization: Bearer <API_TOKEN>" | python3 -m json.tool
   ```

5. `terraform plan` — should show no changes after all records are imported.

### TXT record content format

The Cloudflare provider v5 expects TXT content **without** surrounding double quotes. The provider adds the DNS wire-format quotes itself. If `terraform plan` shows a diff stripping quotes from existing records, run `terraform apply` once to normalize — subsequent plans will be clean.

### DDNS-managed records

Records managed by an external DDNS agent (e.g. `favonia/cloudflare-ddns`) must **not** be declared in `zones.tf` and must **not** be imported into state. Terraform has no knowledge of unmanaged records and will never touch them. Add a comment in `zones.tf` to document which records are excluded and why.

### Adding a new zone

```bash
./scripts/create-cloudflare-zone.sh example.com
```

This appends a stub entry to `zones.tf` and prints the import commands to run. Fill in the DNS records in `zones.tf` before running `terraform apply`.
