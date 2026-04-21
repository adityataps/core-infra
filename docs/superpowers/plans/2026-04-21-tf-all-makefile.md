# Terraform Apply-All Makefile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Makefile-based system to run `terraform plan`/`apply` across all root modules in dependency order, with interactive confirmation, progress display, and CI workflows for plan-on-PR/push and daily drift detection.

**Architecture:** A `Makefile` at repo root declares the dependency graph as Make targets with explicit prerequisites — Make enforces ordering. A per-module executor script (`scripts/tf-module.sh`) handles init/plan/confirm/apply for each target. A CLI wrapper (`scripts/tf-all.sh`) translates `plan`/`apply`/`--auto-approve` into `make` variables and tracks cross-module progress.

**Tech Stack:** GNU Make, Bash (`set -euo pipefail`), Terraform CLI, GitHub Actions (WIF auth via `google-github-actions/auth@v2`)

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `Makefile` | Create | Dependency graph: 15 `.PHONY` targets with explicit prerequisites |
| `scripts/tf-module.sh` | Create | Per-module executor: init → plan → [confirm] → apply; writes to progress dir |
| `scripts/tf-all.sh` | Create | CLI wrapper: arg parsing, progress dir setup, invokes `make all` |
| `.github/workflows/terraform-plan.yml` | Create | Plan on PR + push to main; posts PR comment |
| `.github/workflows/terraform-drift.yml` | Create | Daily 09:00 UTC drift detection; fails on changes |
| `.github/workflows/terraform.yml` | Delete | Superseded by `terraform-plan.yml` |

---

## Dependency Graph (reference for all tasks)

```
Tier 1 (no deps):       github-init  pagerduty  gcp-org  aws-org  hetzner  mongodb  supabase
Tier 2 (→ tier 1):      gcp-management  aws-management
Tier 3 (→ tier 2):      gcp-personal-tapshalkar-com  gcp-personal-sandbox
                        aws-personal-tapshalkar-com  aws-personal-sandbox  aws-certs
Tier 4 (aggregator):    github-sync
```

`github-init` runs `providers/github` first to establish `core_infra_repo_full_name` output.
`github-sync` runs `providers/github` again last to write AWS role ARNs as GitHub Actions secrets.

---

## Task 1: `scripts/tf-module.sh`

**Files:**
- Create: `scripts/tf-module.sh`

This script is called by every Makefile target. It handles `terraform init`, optional plan output + interactive prompt, and `terraform apply`. It also writes progress to a shared temp dir (`$TF_PROGRESS_DIR`) when set by `tf-all.sh`.

- [ ] **Step 1: Create `scripts/tf-module.sh`**

```bash
#!/usr/bin/env bash
# Usage: scripts/tf-module.sh <cmd> <auto_approve> <module_path>
#
#   cmd           plan | apply
#   auto_approve  0 (prompt per module) | 1 (no prompt)
#   module_path   relative to repo root, e.g. providers/gcp/org
#
# Exit codes:
#   0  success (no changes for plan, applied/skipped for apply)
#   1  terraform error
#   2  drift detected (plan mode) or user aborted with 'q' (apply mode)
set -euo pipefail

CMD="$1"
AUTO_APPROVE="$2"
MODULE="$3"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_PATH="$REPO_ROOT/$MODULE"
STATE_BUCKET="tapshalkar-com-tfstate"
PROGRESS_DIR="${TF_PROGRESS_DIR:-}"

# ── Progress header ────────────────────────────────────────────────────────────
if [[ -n "$PROGRESS_DIR" ]]; then
  COUNTER=$(( $(cat "$PROGRESS_DIR/counter") + 1 ))
  printf '%s' "$COUNTER" > "$PROGRESS_DIR/counter"
  TOTAL=$(cat "$PROGRESS_DIR/total")
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "[$COUNTER/$TOTAL] $MODULE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# ── Init ──────────────────────────────────────────────────────────────────────
cd "$MODULE_PATH"
terraform init \
  -backend-config="bucket=$STATE_BUCKET" \
  -reconfigure \
  -input=false \
  -no-color 2>&1 | grep -E "^(Terraform|Error|Warning|Initializing)" || true

# ── Plan ──────────────────────────────────────────────────────────────────────
TFPLAN=$(mktemp /tmp/tf-plan.XXXXXX)
trap 'rm -f "$TFPLAN"' EXIT

if [[ "$CMD" == "plan" ]]; then
  set +e
  terraform plan -detailed-exitcode -input=false -out="$TFPLAN"
  PLAN_EXIT=$?
  set -e

  if [[ -n "$PROGRESS_DIR" ]]; then
    case $PLAN_EXIT in
      0) echo "○ no change  $MODULE" >> "$PROGRESS_DIR/results" ;;
      2) echo "~ changes    $MODULE" >> "$PROGRESS_DIR/results" ;;
      1) echo "✗ error      $MODULE" >> "$PROGRESS_DIR/results" ;;
    esac
  fi
  exit $PLAN_EXIT
fi

# ── Apply ─────────────────────────────────────────────────────────────────────
terraform plan -input=false -out="$TFPLAN"

if [[ "$AUTO_APPROVE" == "1" ]]; then
  terraform apply -input=false "$TFPLAN"
  RESULT="✓ applied    $MODULE"
else
  echo ""
  printf "Apply changes to %s? [y/s/q] " "$MODULE"
  read -r RESPONSE </dev/tty
  case "$RESPONSE" in
    y|Y)
      terraform apply -input=false "$TFPLAN"
      RESULT="✓ applied    $MODULE"
      ;;
    q|Q)
      echo "Aborted."
      exit 2
      ;;
    *)
      echo "Skipping $MODULE"
      RESULT="○ skipped    $MODULE"
      ;;
  esac
fi

[[ -n "$PROGRESS_DIR" ]] && echo "$RESULT" >> "$PROGRESS_DIR/results"
```

- [ ] **Step 2: Make executable and verify syntax**

```bash
chmod +x scripts/tf-module.sh
bash -n scripts/tf-module.sh
```

Expected: no output (clean parse).

- [ ] **Step 3: Verify arg validation exits non-zero on missing args**

```bash
scripts/tf-module.sh 2>&1 || echo "exit $?"
```

Expected: `exit 1` (bash `set -u` fires on unbound `$1`).

- [ ] **Step 4: Commit**

```bash
git add scripts/tf-module.sh
git commit -m "feat(scripts): add tf-module.sh per-module executor"
```

---

## Task 2: `scripts/tf-all.sh`

**Files:**
- Create: `scripts/tf-all.sh`

Thin CLI wrapper. Sets up the progress tracking temp dir, exports `TF_PROGRESS_DIR`, invokes `make all`, then prints the end-of-run summary.

- [ ] **Step 1: Create `scripts/tf-all.sh`**

```bash
#!/usr/bin/env bash
# Usage: scripts/tf-all.sh <plan|apply> [--auto-approve]
#
#   plan                   Preview changes across all modules in dependency order
#   apply                  Apply changes, prompting per module
#   apply --auto-approve   Apply all changes without prompting
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOTAL_MODULES=15  # keep in sync with number of targets called in Makefile `all` chain

# ── Parse args ────────────────────────────────────────────────────────────────
CMD="${1:-}"
AUTO_APPROVE=0

if [[ "$CMD" == "apply" && "${2:-}" == "--auto-approve" ]]; then
  AUTO_APPROVE=1
fi

if [[ "$CMD" != "plan" && "$CMD" != "apply" ]]; then
  echo "Usage: $0 <plan|apply> [--auto-approve]"
  echo ""
  echo "  plan                   Preview changes across all modules"
  echo "  apply                  Apply changes, prompting per module"
  echo "  apply --auto-approve   Apply all changes without prompting"
  exit 1
fi

# ── Progress tracking ─────────────────────────────────────────────────────────
PROGRESS_DIR=$(mktemp -d /tmp/tf-progress.XXXXXX)
trap 'rm -rf "$PROGRESS_DIR"' EXIT

printf '0'              > "$PROGRESS_DIR/counter"
printf '%s' "$TOTAL_MODULES" > "$PROGRESS_DIR/total"
touch "$PROGRESS_DIR/results"

export TF_PROGRESS_DIR="$PROGRESS_DIR"

# ── Run ───────────────────────────────────────────────────────────────────────
cd "$REPO_ROOT"
set +e
make all CMD="$CMD" AUTO_APPROVE="$AUTO_APPROVE"
MAKE_EXIT=$?
set -e

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "Summary (%s modules)\n" "$TOTAL_MODULES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -s "$PROGRESS_DIR/results" ]]; then
  cat "$PROGRESS_DIR/results"
else
  echo "(no modules completed)"
fi
echo ""

exit $MAKE_EXIT
```

- [ ] **Step 2: Make executable and verify syntax**

```bash
chmod +x scripts/tf-all.sh
bash -n scripts/tf-all.sh
```

Expected: no output.

- [ ] **Step 3: Verify usage message on invalid arg**

```bash
scripts/tf-all.sh foo 2>&1; echo "exit $?"
```

Expected output includes `Usage: ...` and `exit 1`.

- [ ] **Step 4: Verify usage message on no arg**

```bash
scripts/tf-all.sh 2>&1; echo "exit $?"
```

Expected: same usage message, `exit 1`.

- [ ] **Step 5: Commit**

```bash
git add scripts/tf-all.sh
git commit -m "feat(scripts): add tf-all.sh CLI wrapper with progress tracking"
```

---

## Task 3: `Makefile`

**Files:**
- Create: `Makefile`

Declares all 15 root module targets as `.PHONY` with explicit prerequisites. Every recipe calls `scripts/tf-module.sh` via the `$(RUN)` variable, which is parameterised by `CMD` and `AUTO_APPROVE`. A separate `ci-plan` target covers only the modules available with GCP WIF auth (same scope as the existing `terraform.yml`).

> **Important:** Makefile recipes must be indented with a **tab character**, not spaces. Every recipe line below uses a tab.

- [ ] **Step 1: Create `Makefile`**

```makefile
# Terraform dependency graph
#
# Local usage (all modules, credentials from .tfvars):
#   make [all]                       # plan all (default)
#   make all CMD=apply               # apply all, prompt per module
#   make all CMD=apply AUTO_APPROVE=1  # apply all without prompting
#
# Or use the wrapper:
#   scripts/tf-all.sh plan
#   scripts/tf-all.sh apply [--auto-approve]
#
# CI usage (GCP WIF auth only):
#   make ci-plan
#
# Run a single target (and its prerequisites):
#   make gcp-management CMD=plan

CMD          ?= plan
AUTO_APPROVE ?= 0

RUN := scripts/tf-module.sh $(CMD) $(AUTO_APPROVE)

.PHONY: all \
        github-init pagerduty gcp-org aws-org hetzner mongodb supabase \
        gcp-management aws-management \
        gcp-personal-tapshalkar-com gcp-personal-sandbox \
        aws-personal-tapshalkar-com aws-personal-sandbox aws-certs \
        github-sync \
        ci-plan

# ── Entry point ───────────────────────────────────────────────────────────────
all: github-sync

# ── Tier 4: github (2nd pass — writes AWS role ARNs as GH Actions secrets) ───
github-sync: gcp-management aws-management \
             gcp-personal-tapshalkar-com gcp-personal-sandbox \
             aws-personal-tapshalkar-com aws-personal-sandbox aws-certs
	@$(RUN) providers/github

# ── Tier 3: depend on management accounts ─────────────────────────────────────
gcp-personal-tapshalkar-com: pagerduty gcp-org github-init gcp-management
	@$(RUN) providers/gcp/projects/personal/tapshalkar-com-personal

gcp-personal-sandbox: pagerduty gcp-org github-init gcp-management
	@$(RUN) providers/gcp/projects/personal/tapshalkar-com-sandbox

aws-personal-tapshalkar-com: pagerduty aws-org github-init aws-management
	@$(RUN) providers/aws/accounts/personal/tapshalkar-com-personal

aws-personal-sandbox: pagerduty aws-org github-init aws-management
	@$(RUN) providers/aws/accounts/personal/tapshalkar-com-sandbox

aws-certs: pagerduty aws-org github-init aws-management
	@$(RUN) providers/aws/accounts/certs/tapshalkar-com-certs

# ── Tier 2: depend on github + pagerduty + org layers ─────────────────────────
gcp-management: pagerduty gcp-org github-init
	@$(RUN) providers/gcp/projects/management/tapshalkar-com

aws-management: pagerduty github-init
	@$(RUN) providers/aws/accounts/management/tapshalkar-com

# ── Tier 1: no cross-module dependencies ──────────────────────────────────────
github-init:
	@$(RUN) providers/github

pagerduty:
	@$(RUN) providers/pagerduty

gcp-org:
	@$(RUN) providers/gcp/org

aws-org:
	@$(RUN) providers/aws/org

hetzner:
	@$(RUN) providers/hetzner

mongodb:
	@$(RUN) providers/mongodb

supabase:
	@$(RUN) providers/supabase

# ── CI: GCP WIF auth only (no AWS/GitHub/third-party credentials needed) ──────
# Remote state for all these modules already exists in GCS, so inter-module
# deps are not needed for plan — the state is read from GCS via WIF auth.
ci-plan:
	@$(RUN) providers/pagerduty
	@$(RUN) providers/gcp/org
	@$(RUN) providers/gcp/projects/management/tapshalkar-com
	@$(RUN) providers/gcp/projects/personal/tapshalkar-com-personal
	@$(RUN) providers/gcp/projects/personal/tapshalkar-com-sandbox
```

- [ ] **Step 2: Verify Makefile syntax**

```bash
make --dry-run all CMD=plan 2>&1 | head -40
```

Expected: 15 lines of `scripts/tf-module.sh plan 0 providers/<module>`, in dependency order. No `make: ***` errors.

- [ ] **Step 3: Verify a single target dry-run shows correct prerequisites**

```bash
make --dry-run gcp-management CMD=plan 2>&1
```

Expected output (order may vary for tier-1 deps):
```
scripts/tf-module.sh plan 0 providers/github
scripts/tf-module.sh plan 0 providers/pagerduty
scripts/tf-module.sh plan 0 providers/gcp/org
scripts/tf-module.sh plan 0 providers/gcp/projects/management/tapshalkar-com
```

- [ ] **Step 4: Verify ci-plan dry-run**

```bash
make --dry-run ci-plan CMD=plan 2>&1
```

Expected: 5 lines, one per GCP + pagerduty module, no prerequisites chained.

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "feat: add Makefile with terraform dependency graph"
```

---

## Task 4: `.github/workflows/terraform-plan.yml`

**Files:**
- Create: `.github/workflows/terraform-plan.yml`
- Delete: `.github/workflows/terraform.yml`

Replaces the existing matrix-based workflow with a single sequential job using `make ci-plan`. Posts a combined plan output as a PR comment. Triggers on PR (all branches) and push to main.

- [ ] **Step 1: Create `.github/workflows/terraform-plan.yml`**

```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main]
    paths:
      - 'providers/**'
      - 'Makefile'
      - 'scripts/**'
  push:
    branches: [main]
    paths:
      - 'providers/**'
      - 'Makefile'
      - 'scripts/**'

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
      pull-requests: write

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

      - name: Terraform Plan
        id: plan
        run: |
          set +e
          make ci-plan CMD=plan 2>&1 | tee plan_output.txt
          PLAN_EXIT=${PIPESTATUS[0]}
          set -e
          echo "exit_code=$PLAN_EXIT" >> "$GITHUB_OUTPUT"
          {
            echo "plan_output<<EOF"
            cat plan_output.txt
            echo "EOF"
          } >> "$GITHUB_OUTPUT"
          # Exit 2 = changes detected (not an error for plan workflow)
          [[ $PLAN_EXIT -eq 1 ]] && exit 1 || exit 0

      - name: Post Plan Comment
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const exitCode = '${{ steps.plan.outputs.exit_code }}';
            const planOutput = `${{ steps.plan.outputs.plan_output }}`.trim();
            const status = exitCode === '0' ? '✅ No changes' :
                           exitCode === '2' ? '⚠️ Changes detected' : '❌ Error';

            const maxLength = 60000;
            const truncated = planOutput.length > maxLength
              ? planOutput.substring(0, maxLength) + '\n\n... output truncated (exceeded 60,000 chars)'
              : planOutput;

            const body = [
              `### ${status}: Terraform Plan`,
              '',
              '<details><summary>Show plan output</summary>',
              '',
              '```',
              truncated,
              '```',
              '',
              '</details>'
            ].join('\n');

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body
            });
```

- [ ] **Step 2: Delete the old workflow**

```bash
git rm .github/workflows/terraform.yml
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/terraform-plan.yml
git commit -m "ci: replace matrix plan workflow with sequential Makefile-based plan"
```

---

## Task 5: `.github/workflows/terraform-drift.yml`

**Files:**
- Create: `.github/workflows/terraform-drift.yml`

Runs `make ci-plan` on a daily schedule. Exits non-zero (and triggers GitHub notification) when any module has changes (exit 2) or errors (exit 1).

- [ ] **Step 1: Create `.github/workflows/terraform-drift.yml`**

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
        run: |
          set +e
          make ci-plan CMD=plan
          EXIT=$?
          set -e
          if [[ $EXIT -eq 2 ]]; then
            echo "::warning::Drift detected — one or more modules have changes outside Terraform state."
          fi
          exit $EXIT
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/terraform-drift.yml
git commit -m "ci: add daily terraform drift detection workflow"
```

---

## Task 6: Smoke Test

Manual verification that the wiring is correct end-to-end before pushing to CI.

- [ ] **Step 1: Verify `tf-all.sh plan` dry-runs cleanly (no actual terraform)**

```bash
# Confirm Make dry-run resolves all 15 modules in the right order
make --dry-run all CMD=plan 2>&1
```

Expected: 15 `scripts/tf-module.sh plan 0 providers/...` lines. First line is `providers/github`, last line is `providers/github` (again, for `github-sync`).

- [ ] **Step 2: Verify the argument guard**

```bash
scripts/tf-all.sh badarg; echo "exit: $?"
scripts/tf-all.sh; echo "exit: $?"
scripts/tf-all.sh apply notaflag; echo "exit: $?"
```

Expected: usage text printed and `exit: 1` for each.

- [ ] **Step 3: Verify `--auto-approve` is passed correctly to Make**

```bash
make --dry-run all CMD=apply AUTO_APPROVE=1 2>&1 | head -3
```

Expected: `scripts/tf-module.sh apply 1 providers/github` (AUTO_APPROVE=1 is threaded through).

- [ ] **Step 4: Confirm old workflow is gone**

```bash
ls .github/workflows/
```

Expected: `terraform-drift.yml  terraform-plan.yml` (no `terraform.yml`).

- [ ] **Step 5: Final commit if anything was missed**

```bash
git status
# If clean, nothing to do. If not:
git add -p
git commit -m "chore: tf-all smoke test fixes"
```
