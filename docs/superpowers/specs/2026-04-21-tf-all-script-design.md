# Design: Terraform Apply-All Script + CI Workflows

**Date:** 2026-04-21
**Status:** Approved

---

## Overview

A bash script (`scripts/tf-all.sh`) that runs `terraform init` + `terraform plan` or `terraform apply` across all root modules in dependency order. Paired with two GitHub Actions workflows: one for plan-on-PR/push, one for daily drift detection.

---

## Scope

**In scope:**
- `scripts/tf-all.sh` — ordered plan/apply runner
- `.github/workflows/terraform-plan.yml` — plan on PR + push to main
- `.github/workflows/terraform-drift.yml` — scheduled daily drift detection

**Out of scope:**
- `bootstrap/` — excluded (run-once, local state)
- `providers/*/modules/` — excluded (reusable modules, not root modules)
- Parallelism (deferred; Makefile approach can be revisited later)

---

## Dependency Graph & Apply Order

The repo has a cycle between `github` and the AWS accounts:
- All AWS accounts read `github.outputs.core_infra_repo_full_name` (stable repo name string)
- `github` reads `github_actions_role_arn` outputs from all AWS accounts to write back as GitHub Actions secrets

The cycle breaks cleanly by applying `github` twice: first to establish the repo name output, last to populate the role ARN secrets.

```
# Tier 1 — no cross-module dependencies
providers/github                                          # 1st pass: establishes core_infra_repo_full_name
providers/pagerduty
providers/gcp/org
providers/aws/org
providers/hetzner
providers/mongodb
providers/supabase

# Tier 2 — depend on github + pagerduty + org layers
providers/gcp/projects/management/tapshalkar-com         # needs: pagerduty, gcp/org, github
providers/aws/accounts/management/tapshalkar-com         # needs: pagerduty, github

# Tier 3 — depend on management accounts
providers/gcp/projects/personal/tapshalkar-com-personal  # needs: pagerduty, gcp/org, github, gcp/projects/management
providers/gcp/projects/personal/tapshalkar-com-sandbox   # needs: pagerduty, gcp/org, github, gcp/projects/management
providers/aws/accounts/personal/tapshalkar-com-personal  # needs: pagerduty, aws/org, github, aws/accounts/management
providers/aws/accounts/personal/tapshalkar-com-sandbox   # needs: pagerduty, aws/org, github, aws/accounts/management
providers/aws/accounts/certs/tapshalkar-com-certs        # needs: pagerduty, aws/org, github, aws/accounts/management

# Tier 4 — aggregator (re-apply to write role ARNs as GitHub Actions secrets)
providers/github                                          # 2nd pass: writes AWS role ARNs back as GH Actions secrets
```

---

## Script Design (`scripts/tf-all.sh`)

**Interface:**
```bash
./scripts/tf-all.sh plan    # runs terraform init + plan on all modules
./scripts/tf-all.sh apply   # runs terraform init + apply -auto-approve on all modules
```

**Behavior:**
- Iterates the hardcoded `MODULES` array in order
- For each module: prints a clear header, runs `terraform init -reconfigure`, then runs the requested command
- Fails fast: exits non-zero immediately if any module fails
- `plan` mode: `terraform plan -detailed-exitcode` — exits 2 if changes detected (useful for drift detection)
- `apply` mode: `terraform apply -auto-approve`
- Validates that the argument is `plan` or `apply`; prints usage and exits on invalid input

**Extending the script:**
When a new root module is added, insert it into the `MODULES` array at the appropriate tier and add a comment noting its dependencies.

---

## GitHub Actions: Plan Workflow (`.github/workflows/terraform-plan.yml`)

**Triggers:** `pull_request` (all branches) + `push` to `main`

**Auth:** GCP Workload Identity Federation using existing repo secrets:
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`

**Steps:**
1. Checkout repo
2. Authenticate to GCP via WIF (`google-github-actions/auth`)
3. Set up Terraform
4. Run `./scripts/tf-all.sh plan`

**On failure:** The workflow step fails and blocks the PR (for PR triggers).

---

## GitHub Actions: Drift Detection Workflow (`.github/workflows/terraform-drift.yml`)

**Trigger:** `schedule: cron: '0 9 * * *'` (daily at 09:00 UTC)
- Only runs on the default branch (`main`)
- GitHub disables scheduled workflows after 60 days of repo inactivity — worth knowing for a personal repo

**Auth:** Same GCP WIF secrets as the plan workflow

**Steps:**
1. Checkout repo
2. Authenticate to GCP via WIF
3. Set up Terraform
4. Run `./scripts/tf-all.sh plan`

**Drift signaling:** `terraform plan -detailed-exitcode` returns exit code 2 when changes are detected. The script propagates this, causing the workflow run to fail — triggering a GitHub notification to the repo owner.

---

## Error Handling

- Invalid argument → print usage, exit 1
- Any module `init` or `plan`/`apply` failure → print which module failed, exit 1 immediately (fail fast)
- No attempt to continue past a failed module — downstream modules may depend on the failed one's state

---

## Files to Create

| Path | Purpose |
|------|---------|
| `scripts/tf-all.sh` | Ordered plan/apply runner |
| `.github/workflows/terraform-plan.yml` | Plan on PR + push to main |
| `.github/workflows/terraform-drift.yml` | Daily drift detection |
