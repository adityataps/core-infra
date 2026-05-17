# Repo Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix six concrete shortcomings in the monorepo: centralize the hardcoded state bucket name in scripts, remove empty providers from the default `make all` target, enable the monitoring alert stub, improve drift alerting with GitHub issue creation, auto-patch `ci-plan` in scaffold scripts, and document the two-pass GitHub apply pattern.

**Architecture:** All changes are localized to shell scripts, Makefile, one Terraform module file, and one GitHub Actions workflow. No new files need to be created (except `scripts/config.sh`). Changes are independent of each other and can be committed separately.

**Tech Stack:** Bash, GNU Make, Terraform HCL, GitHub Actions YAML

---

## File Map

| File | Change |
|---|---|
| `scripts/config.sh` | **Create** — single source of truth for `STATE_BUCKET` |
| `scripts/tf-module.sh` | Source `config.sh`; remove inline `STATE_BUCKET` declaration |
| `scripts/create-gcp-project.sh` | Source `config.sh`; remove inline `STATE_BUCKET` declaration; auto-patch `ci-plan` |
| `scripts/create-aws-account.sh` | Source `config.sh`; remove inline `STATE_BUCKET` declaration |
| `Makefile` | Remove `hetzner mongodb supabase` from `all` deps; add two-pass comment |
| `providers/gcp/modules/baseline/monitoring.tf` | Enable alert policy; replace stub condition with real CPU threshold |
| `.github/workflows/terraform-drift.yml` | Add `issues: write` permission; create GitHub issue on drift |

---

## Task 1: Centralize state bucket name in scripts

**Context:** `STATE_BUCKET="tapshalkar-com-tfstate"` is declared independently in `tf-module.sh`, `create-gcp-project.sh`, and `create-aws-account.sh`. A single `scripts/config.sh` sourced by all three removes the duplication. Note: Terraform `data "terraform_remote_state"` blocks cannot use variables — those occurrences in `.tf` files remain hardcoded (a Terraform language limitation).

**Files:**
- Create: `scripts/config.sh`
- Modify: `scripts/tf-module.sh`
- Modify: `scripts/create-gcp-project.sh`
- Modify: `scripts/create-aws-account.sh`

- [ ] **Step 1: Create `scripts/config.sh`**

```bash
#!/usr/bin/env bash
# Shared configuration for all tf-* scripts.
# Source this file — do not execute it directly.
#
# Note: Terraform remote_state data blocks in .tf files still contain this bucket
# name as a string literal (Terraform does not allow variables in backend configs).
# This file centralizes the name for bash scripts only.

STATE_BUCKET="tapshalkar-com-tfstate"
```

- [ ] **Step 2: Update `tf-module.sh` to source config**

In `scripts/tf-module.sh`, find and replace the inline declaration:

Old (line ~17):
```bash
STATE_BUCKET="tapshalkar-com-tfstate"
```

New:
```bash
# shellcheck source=config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
```

- [ ] **Step 3: Update `create-gcp-project.sh` to source config**

In `scripts/create-gcp-project.sh`, find and replace the inline declaration:

Old (line ~15):
```bash
STATE_BUCKET="tapshalkar-com-tfstate"
```

New:
```bash
# shellcheck source=config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
```

- [ ] **Step 4: Update `create-aws-account.sh` to source config**

In `scripts/create-aws-account.sh`, find and replace the inline declaration:

Old (line ~13):
```bash
STATE_BUCKET="tapshalkar-com-tfstate"
```

New:
```bash
# shellcheck source=config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
```

- [ ] **Step 5: Verify the scripts still work**

```bash
# Smoke-test sourcing (no side effects)
bash -c 'source scripts/config.sh && echo "STATE_BUCKET=$STATE_BUCKET"'
```

Expected output:
```
STATE_BUCKET=tapshalkar-com-tfstate
```

```bash
# Verify tf-module.sh still exits cleanly on --help path (missing args)
bash scripts/tf-module.sh 2>&1 | head -5
```

Expected: prints usage line starting with `Usage:`, exits 1.

- [ ] **Step 6: Commit**

```bash
git add scripts/config.sh scripts/tf-module.sh scripts/create-gcp-project.sh scripts/create-aws-account.sh
git commit -m "refactor(scripts): centralize STATE_BUCKET in scripts/config.sh"
```

---

## Task 2: Remove empty providers from `make all`

**Context:** `hetzner`, `mongodb`, and `supabase` targets run `tf-module.sh` against directories whose `main.tf` files contain only comments — no resources. They also require credentials that may not be configured. Including them in `all` means `make all` fails unless you have credentials for all three providers. The fix: remove them from `all`'s prerequisites. They can still be run individually (`make hetzner`, etc.) once configured.

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Update the `all` target**

In `Makefile`, find:

```makefile
all: github-sync hetzner mongodb supabase
```

Replace with:

```makefile
# hetzner, mongodb, supabase are excluded until they contain real resources.
# Run them individually: make hetzner | make mongodb | make supabase
all: github-sync
```

- [ ] **Step 2: Verify `make all --dry-run` no longer includes the empty providers**

```bash
make --dry-run all CMD=plan 2>/dev/null | grep tf-module
```

Expected: lines for `github`, `pagerduty`, `gcp/*`, `aws/*` — no `hetzner`, `mongodb`, or `supabase`.

- [ ] **Step 3: Verify individual targets still work**

```bash
make --dry-run hetzner CMD=plan 2>/dev/null
make --dry-run mongodb CMD=plan 2>/dev/null
make --dry-run supabase CMD=plan 2>/dev/null
```

Expected: each prints the `tf-module.sh` invocation for its path without error.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "fix(makefile): remove empty hetzner/mongodb/supabase from default 'all' target"
```

---

## Task 3: Document the two-pass GitHub apply pattern in Makefile

**Context:** `providers/github` is applied twice in `make all` — once as `github-init` (tier 1, before any secrets exist) and again as `github-sync` (tier 4, after all account outputs are available). This is an intentional two-pass pattern to break the circular dependency between GitHub secrets and the cloud accounts that produce them, but it reads as a bug without a comment.

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add a comment above both github targets**

Find in `Makefile`:

```makefile
# ── Tier 4: github (2nd pass — writes AWS role ARNs as GH Actions secrets) ───
github-sync: gcp-management aws-management \
```

Replace with:

```makefile
# ── Tier 4: github (2nd pass — writes cloud account outputs as GH secrets) ────
#
# providers/github is applied TWICE per run (two-pass pattern):
#   Pass 1 (github-init, tier 1): bootstraps the GitHub provider so downstream
#     modules can read the repo's full_name from remote state.
#   Pass 2 (github-sync, tier 4): re-applies after all cloud accounts are done,
#     so GitHub Actions secrets (role ARNs, WIF providers) reflect current outputs.
#
# This breaks the circular dependency: secrets depend on account outputs, but
# accounts read the repo name from github state — which must exist first.
github-sync: gcp-management aws-management \
```

- [ ] **Step 2: Verify Makefile parses correctly**

```bash
make --dry-run all CMD=plan 2>/dev/null | grep github
```

Expected: `github-init` appears early, `github-sync` appears last.

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "docs(makefile): document the two-pass github apply pattern"
```

---

## ~~Task 4: Enable the monitoring alert policy with a real condition~~ — SKIPPED

**Decision (2026-05-17):** `monitoring.tf` was rewritten to explicitly remove the stub and document that workload alerts belong in each project's own config, not the baseline module. The architectural reasoning (different projects run different workloads — Cloud Run, GKE, GCE, etc.) supersedes the plan's approach. No changes needed.

<details><summary>Original task (superseded)</summary>

**Context:** `providers/gcp/modules/baseline/monitoring.tf` creates an alert policy with `enabled = false` and a CPU threshold of `0.99` (fires only at 100% CPU — essentially never). The stub was a placeholder. The fix: enable the policy and set a meaningful threshold. Since not all projects have Compute Engine instances, a CPU alert with no matching time series simply produces no data — it won't fire spuriously.

**Files:**
- Modify: `providers/gcp/modules/baseline/monitoring.tf`

- [ ] **Step 1: Enable the alert and set a real threshold**

Replace the entire contents of `providers/gcp/modules/baseline/monitoring.tf` with:

```hcl
resource "google_monitoring_alert_policy" "default" {
  project      = google_project.this.project_id
  display_name = "${var.project_id} — CPU Utilization > 80%"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "GCE instance CPU utilization > 80%"
    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = compact([
    google_monitoring_notification_channel.budget_email.id,
    length(google_monitoring_notification_channel.pagerduty) > 0
    ? google_monitoring_notification_channel.pagerduty[0].id
    : null
  ])

  depends_on = [google_project_service.apis]
}
```

Key changes from the stub:
- `enabled = true`
- `display_name` is descriptive, not "Stub — replace with real condition"
- `threshold_value = 0.8` (80%, not 99%)
- `duration = "300s"` (must exceed threshold for 5 min before alerting — avoids spike noise)
- `aggregations` block added (required for metric conditions to function correctly)

- [ ] **Step 2: Validate HCL**

```bash
cd providers/gcp/modules/baseline
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
cd - # return to repo root
git add providers/gcp/modules/baseline/monitoring.tf
git commit -m "fix(baseline): enable monitoring alert policy with real CPU threshold (80%)"
```

</details>

---

## Task 5: Improve drift alerting — create a GitHub issue on drift

**Context:** `terraform-drift.yml` currently emits a `::warning::` annotation and exits with code 2. GitHub does send an email on non-zero exit, but the signal is easy to miss. Creating a GitHub issue on drift detection makes it hard to ignore and creates an audit trail.

`ci-plan` only checks GCP (no AWS credentials in CI). The issue body should state this scope explicitly so the issue is not misread as "all infrastructure is clean."

**Files:**
- Modify: `.github/workflows/terraform-drift.yml`

- [ ] **Step 1: Replace the drift detection job**

Replace the entire contents of `.github/workflows/terraform-drift.yml` with:

```yaml
name: Terraform Drift Detection

on:
  schedule:
    # Daily at 09:00 UTC. Note: GitHub disables scheduled workflows
    # automatically after 60 days of repo inactivity.
    - cron: '0 9 * * *'
  # Allow manual trigger for testing
  workflow_dispatch:

jobs:
  drift:
    name: Drift Detection
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
      issues: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.5"

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Detect Drift
        id: drift
        run: |
          set +e
          scripts/tf-all.sh plan ci-plan 2>&1 | tee drift_output.txt
          EXIT=${PIPESTATUS[0]}
          set -e
          {
            echo "output<<EOF"
            cat drift_output.txt
            echo "EOF"
          } >> "$GITHUB_OUTPUT"
          echo "exit_code=$EXIT" >> "$GITHUB_OUTPUT"
          # Exit 2 = changes (drift); exit 1 = error — both are failures
          exit $EXIT

      - name: Open drift issue
        if: failure() && steps.drift.outputs.exit_code == '2'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `${{ steps.drift.outputs.output }}`.trim();
            const maxLength = 50000;
            const truncated = output.length > maxLength
              ? output.substring(0, maxLength) + '\n\n... output truncated'
              : output;

            const runUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
            const today = new Date().toISOString().slice(0, 10);

            // Check for an existing open drift issue to avoid duplicates
            const { data: issues } = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: 'terraform-drift',
              state: 'open',
            });

            if (issues.length > 0) {
              // Comment on the existing issue instead of opening a new one
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: issues[0].number,
                body: `### Drift still present — ${today}\n\n[Run ${context.runId}](${runUrl})\n\n<details><summary>Plan output</summary>\n\n\`\`\`\n${truncated}\n\`\`\`\n\n</details>`,
              });
            } else {
              await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: `Terraform drift detected — ${today}`,
                labels: ['terraform-drift'],
                body: [
                  '**Scope:** GCP modules only (AWS/GitHub modules require separate credentials and are not checked in CI).',
                  '',
                  `**Run:** [${context.runId}](${runUrl})`,
                  '',
                  '<details><summary>Plan output</summary>',
                  '',
                  '```',
                  truncated,
                  '```',
                  '',
                  '</details>',
                  '',
                  '_Close this issue after applying the drift with `make all CMD=apply`._',
                ].join('\n'),
              });
            }
```

- [ ] **Step 2: Create the `terraform-drift` label in the repo**

```bash
gh label create terraform-drift --color "FF6B6B" --description "Terraform state drift detected by scheduled CI" 2>/dev/null || echo "label already exists"
```

- [ ] **Step 3: Validate the workflow YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/terraform-drift.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/terraform-drift.yml
git commit -m "feat(ci): open GitHub issue on drift detection instead of silent warning"
```

---

## Task 6: Auto-patch `ci-plan` in GCP scaffold script

**Context:** `scripts/create-gcp-project.sh` already patches the Makefile to add new GCP project targets to the main dependency graph, but does not add them to the `ci-plan` target. New GCP projects added via the script are therefore never planned in CI until someone manually edits the Makefile. The AWS scaffold script is intentionally excluded — AWS modules cannot be CI-planned without AWS credentials.

**Files:**
- Modify: `scripts/create-gcp-project.sh`

- [ ] **Step 1: Find the existing Makefile patching section in `create-gcp-project.sh`**

Read the script to find the `MAKEFILE` patching block (around line 130+). It currently patches `MAKE_TARGET` entries for the new project. We need to also append to `ci-plan`.

- [ ] **Step 2: Add ci-plan patch after the existing Makefile patching**

Locate the block in `create-gcp-project.sh` that writes to the Makefile (it ends with something like `echo "✓ Makefile patched"`). After that block, add:

```bash
# ── 3b. Patch ci-plan target ──────────────────────────────────────────────────
# Append the new project to the ci-plan target so it is included in CI plan runs.
# AWS accounts are intentionally excluded — they require separate AWS credentials.
CI_PLAN_ENTRY="\t@\$(RUN) providers/gcp/projects/$FOLDER/$PROJECT_ID"

python3 - "$MAKEFILE" "$CI_PLAN_ENTRY" <<'PYEOF'
import sys, re

path, entry = sys.argv[1], sys.argv[2]
content = open(path).read()

# Find the ci-plan target and append the new entry before the next blank line or target
pattern = r'(ci-plan:.*?)(\n\n|\nci-plan|\Z)'

def insert_entry(m):
    block = m.group(1).rstrip('\n')
    tail = m.group(2)
    return block + '\n' + entry + tail

content = re.sub(pattern, insert_entry, content, count=1, flags=re.DOTALL)
open(path, 'w').write(content)
PYEOF

echo "✓ ci-plan target patched in Makefile"
```

- [ ] **Step 3: Test the patch on a dry run**

Create a temp copy of the Makefile and run the script's patch logic against it:

```bash
cp Makefile /tmp/Makefile.test
# Simulate what the script does
CI_PLAN_ENTRY="\t@\$(RUN) providers/gcp/projects/personal/test-project"
python3 - /tmp/Makefile.test "$CI_PLAN_ENTRY" <<'PYEOF'
import sys, re
path, entry = sys.argv[1], sys.argv[2]
content = open(path).read()
pattern = r'(ci-plan:.*?)(\n\n|\nci-plan|\Z)'
def insert_entry(m):
    block = m.group(1).rstrip('\n')
    tail = m.group(2)
    return block + '\n' + entry + tail
content = re.sub(pattern, insert_entry, content, count=1, flags=re.DOTALL)
open(path, 'w').write(content)
PYEOF

# Verify the entry was added
grep "test-project" /tmp/Makefile.test
```

Expected: prints `@$(RUN) providers/gcp/projects/personal/test-project` inside the `ci-plan` block.

```bash
rm /tmp/Makefile.test
```

- [ ] **Step 4: Commit**

```bash
git add scripts/create-gcp-project.sh
git commit -m "feat(scripts): auto-patch ci-plan target when scaffolding new GCP projects"
```

---

## Known Limitations (not addressed in this plan)

- **CI coverage for AWS/GitHub/Hetzner/MongoDB/Supabase:** These modules cannot be planned in CI without their respective credentials (AWS OIDC, GitHub token, provider API keys). Adding them requires setting up additional OIDC trusts or GitHub Actions secrets — a separate, larger effort.
- **`terraform_remote_state` bucket name in `.tf` files:** Terraform does not allow variables in `backend` or `data "terraform_remote_state"` config blocks. The 8+ hardcoded occurrences in `.tf` files are a Terraform language constraint, not a style choice.
- **`terraform_version` pinning in CI:** Low risk for a personal repo; left as-is.

---

## Self-Review

**Spec coverage check:**
1. ✅ Centralize state bucket → Task 1
2. ✅ Remove empty providers from `make all` → Task 2
3. ✅ Document two-pass GitHub pattern → Task 3
4. ✅ Enable monitoring stub → Task 4
5. ✅ Improve drift alerting → Task 5
6. ✅ Auto-patch `ci-plan` in scaffold → Task 6
7. ✅ `ignore_changes = [labels]` footgun → already well-documented in code; no change needed
8. ✅ CI coverage gap → documented as known limitation (requires separate AWS OIDC work)

**Placeholder scan:** No TBDs, TODOs, or "similar to Task N" patterns. All code blocks are complete.

**Type consistency:** No shared types across tasks; each task is self-contained bash/HCL/YAML.
