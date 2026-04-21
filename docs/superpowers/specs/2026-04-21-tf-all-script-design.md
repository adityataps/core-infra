# Design: Terraform Apply-All Makefile + CI Workflows

**Date:** 2026-04-21
**Status:** Approved

---

## Overview

A `Makefile` at the repo root defines the dependency graph for all root Terraform modules. A helper script (`scripts/tf-module.sh`) handles per-module execution — plan, interactive confirmation, and apply. A thin wrapper (`scripts/tf-all.sh`) provides a friendly CLI entry point. Two GitHub Actions workflows cover plan-on-PR/push and daily drift detection.

---

## Scope

**In scope:**
- `Makefile` — dependency graph + targets
- `scripts/tf-module.sh` — per-module executor (plan, confirm, apply)
- `scripts/tf-all.sh` — CLI wrapper (`plan` / `apply` / `apply --auto-approve`)
- `.github/workflows/terraform-plan.yml` — plan on PR + push to main
- `.github/workflows/terraform-drift.yml` — scheduled daily drift detection

**Out of scope:**
- `bootstrap/` — excluded (run-once, local state)
- `providers/*/modules/` — excluded (reusable modules, not root modules)
- Parallel execution (`make -j`) — not used; sequential execution is correct given dependencies

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

# Tier 4 — aggregator
providers/github                                          # 2nd pass: writes AWS role ARNs back as GH Actions secrets
```

---

## Makefile Design

The Makefile lives at the repo root. Each root module becomes a `.PHONY` target. Dependencies are declared explicitly — Make enforces them, unlike comments in a bash array.

The `github` double-apply is handled with two distinct targets: `github-init` (tier 1) and `github-sync` (tier 4).

**Variables (overridable from CLI or CI):**
- `CMD` — `plan` or `apply` (default: `plan`)
- `AUTO_APPROVE` — `0` or `1` (default: `0`)

**Example target declarations:**
```makefile
.PHONY: github-init pagerduty gcp-org aws-org
.PHONY: gcp-management aws-management
.PHONY: gcp-personal-tapshalkar-com gcp-personal-sandbox
.PHONY: aws-personal-tapshalkar-com aws-personal-sandbox aws-certs
.PHONY: github-sync
.PHONY: all

CMD         ?= plan
AUTO_APPROVE ?= 0

github-init:
    @scripts/tf-module.sh $(CMD) $(AUTO_APPROVE) providers/github

pagerduty:
    @scripts/tf-module.sh $(CMD) $(AUTO_APPROVE) providers/pagerduty

gcp-org:
    @scripts/tf-module.sh $(CMD) $(AUTO_APPROVE) providers/gcp/org

# ... (aws-org, hetzner, mongodb, supabase similarly)

gcp-management: pagerduty gcp-org github-init
    @scripts/tf-module.sh $(CMD) $(AUTO_APPROVE) providers/gcp/projects/management/tapshalkar-com

aws-management: pagerduty github-init
    @scripts/tf-module.sh $(CMD) $(AUTO_APPROVE) providers/aws/accounts/management/tapshalkar-com

gcp-personal-tapshalkar-com: pagerduty gcp-org github-init gcp-management
    @scripts/tf-module.sh $(CMD) $(AUTO_APPROVE) providers/gcp/projects/personal/tapshalkar-com-personal

# ... (remaining tier 3 targets similarly)

github-sync: gcp-management aws-management gcp-personal-tapshalkar-com \
             gcp-personal-sandbox aws-personal-tapshalkar-com \
             aws-personal-sandbox aws-certs
    @scripts/tf-module.sh $(CMD) $(AUTO_APPROVE) providers/github

all: github-sync
```

**Adding a new module:** Declare a new `.PHONY` target, list its prerequisites, call `scripts/tf-module.sh`. Add it as a prerequisite of any downstream targets that depend on it.

---

## Per-Module Executor (`scripts/tf-module.sh`)

Called by every Makefile target. Handles init, plan, optional interactive confirmation, and apply.

**Signature:** `scripts/tf-module.sh <cmd> <auto_approve> <module_path>`

**Flow for `apply` without `--auto-approve` (`auto_approve=0`):**
```
1. cd <module_path>
2. terraform init -reconfigure -input=false
3. terraform plan -out=tfplan  (saved to a temp plan file)
4. Print plan output
5. Prompt: "Apply changes to <module_path>? [y/s/q]"
     y → terraform apply tfplan
     s → skip (print "Skipping <module>" and exit 0)
     q → exit with a special code (2) to signal abort to Make
6. Clean up tfplan file
```

**Flow for `apply --auto-approve` (`auto_approve=1`):**
```
1-3. Same as above
4. terraform apply -auto-approve
```

**Flow for `plan`:**
```
1. cd <module_path>
2. terraform init -reconfigure -input=false
3. terraform plan -detailed-exitcode
   Exit 0 = no changes, exit 2 = changes detected (propagated to Make/CI)
```

**Exit codes:**
- `0` — success (no changes for plan, applied/skipped for apply)
- `1` — Terraform error
- `2` — user aborted (`q`) or drift detected (plan mode)

---

## CLI Wrapper (`scripts/tf-all.sh`)

Thin entry point that translates friendly CLI args into `make` variables.

**Interface:**
```bash
scripts/tf-all.sh plan                # plan all modules
scripts/tf-all.sh apply               # apply all, prompt per module
scripts/tf-all.sh apply --auto-approve  # apply all without prompting
```

Internally calls: `make all CMD=<cmd> AUTO_APPROVE=<0|1>`

---

## Progress Display

Since modules run sequentially, each module prints a clear section header when it starts and a status line when it finishes. Make's `@` prefix suppresses recipe echoing so only the script's own output appears.

**Per-module output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[4/14] providers/gcp/projects/management/tapshalkar-com
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
... terraform output ...

Apply changes to providers/gcp/projects/management/tapshalkar-com? [y/s/q] y
✓ applied providers/gcp/projects/management/tapshalkar-com
```

**End-of-run summary:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary (14 modules)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓  applied   providers/github (pass 1)
✓  applied   providers/pagerduty
○  no change providers/gcp/org
✓  applied   providers/gcp/projects/management/tapshalkar-com
...
```

The total module count (`[4/14]`) is tracked via a shared counter in a temp file written by `tf-module.sh` and read at summary time.

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
4. Run `scripts/tf-all.sh plan` (calls `make all CMD=plan`)

---

## GitHub Actions: Drift Detection Workflow (`.github/workflows/terraform-drift.yml`)

**Trigger:** `schedule: cron: '0 9 * * *'` (daily at 09:00 UTC)
- Only runs on the default branch (`main`)
- GitHub disables scheduled workflows after 60 days of repo inactivity

**Auth:** Same GCP WIF secrets as the plan workflow

**Steps:**
1. Checkout repo
2. Authenticate to GCP via WIF
3. Set up Terraform
4. Run `scripts/tf-all.sh plan`

**Drift signaling:** `terraform plan -detailed-exitcode` returns exit code 2 when changes are detected. This propagates through `tf-module.sh` → Make → `tf-all.sh`, causing the workflow run to fail and triggering a GitHub notification.

---

## Files to Create / Modify

| Path | Purpose |
|------|---------|
| `Makefile` | Dependency graph + targets (new) |
| `scripts/tf-module.sh` | Per-module executor: init, plan, confirm, apply (new) |
| `scripts/tf-all.sh` | CLI wrapper: translates args into `make` invocation (new) |
| `.github/workflows/terraform-plan.yml` | Plan on PR + push to main (new) |
| `.github/workflows/terraform-drift.yml` | Daily drift detection (new) |
