# tapshalkar-com-web GCP Project Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the `tapshalkar-com-web` GCP project into the monorepo under `providers/gcp/projects/personal/`, with both scaffold scripts updated to generate `backend.hcl` explicitly.

**Architecture:** Update `create-gcp-project.sh` and `create-aws-account.sh` to explicitly write `backend.hcl` from `$STATE_BUCKET` (sourced from `config.sh`), then run the GCP script to scaffold the new project, then apply three web-specific patches to the generated `variables.tf`.

**Tech Stack:** Bash, Python 3 (embedded in scripts), Terraform HCL

---

## File Map

| File | Action |
|------|--------|
| `scripts/create-gcp-project.sh` | Modify — add explicit `backend.hcl` write after template copy |
| `scripts/create-aws-account.sh` | Modify — add `backend.hcl` write alongside existing file writes |
| `providers/gcp/projects/personal/tapshalkar-com-web/` | Created by script (all files) |
| `providers/gcp/projects/personal/tapshalkar-com-web/variables.tf` | Post-scaffold patch — web-specific defaults |
| `Makefile` | Patched by script — new `gcp-personal-tapshalkar-com-web` target |
| `scripts/tf-all.sh` | Patched by script — `TOTAL_MODULES` incremented |

---

## Task 1: Add explicit `backend.hcl` generation to `create-gcp-project.sh`

**Files:**
- Modify: `scripts/create-gcp-project.sh`

The script currently gets `backend.hcl` by accident — it copies the management template and never deletes it. We want it generated explicitly from `$STATE_BUCKET` so it stays in sync with `config.sh`.

- [ ] **Step 1: Open `scripts/create-gcp-project.sh` and locate the rm line**

  The relevant section is around line 58:
  ```bash
  rm -rf "$TARGET/.terraform" "$TARGET/.terraform.lock.hcl" "$TARGET/terraform.tfvars" "$TARGET/README.md"
  ```

- [ ] **Step 2: Add explicit `backend.hcl` generation immediately after the rm line**

  Insert this block after the `rm -rf` line:
  ```bash
  # ── Generate backend.hcl ──────────────────────────────────────────────────────
  cat > "$TARGET/backend.hcl" <<EOF
  bucket = "$STATE_BUCKET"
  EOF
  ```

  The full patched section should read:
  ```bash
  # Remove files that should not be copied
  rm -rf "$TARGET/.terraform" "$TARGET/.terraform.lock.hcl" "$TARGET/terraform.tfvars" "$TARGET/README.md"

  # ── Generate backend.hcl ──────────────────────────────────────────────────────
  cat > "$TARGET/backend.hcl" <<EOF
  bucket = "$STATE_BUCKET"
  EOF
  ```

- [ ] **Step 3: Verify the change looks correct**

  ```bash
  grep -n "backend.hcl\|STATE_BUCKET" scripts/create-gcp-project.sh
  ```

  Expected output includes the new `cat > "$TARGET/backend.hcl"` line.

---

## Task 2: Add `backend.hcl` generation to `create-aws-account.sh`

**Files:**
- Modify: `scripts/create-aws-account.sh`

The AWS script generates all account files via `cat >` heredocs but never creates `backend.hcl`. Add it alongside the other file writes.

- [ ] **Step 1: Locate the `README.md` write in `scripts/create-aws-account.sh`**

  Around line 173–183:
  ```bash
  # README.md
  cat > "$TARGET/README.md" <<EOF
  # \`$OU/$ACCOUNT_NAME\`

  <!-- BEGIN_TF_DOCS -->

  <!-- END_TF_DOCS -->
  EOF

  echo "✓ Account root files written to providers/aws/accounts/$OU/$ACCOUNT_NAME/"
  ```

- [ ] **Step 2: Insert `backend.hcl` generation between the `README.md` write and the echo**

  The section should become:
  ```bash
  # README.md
  cat > "$TARGET/README.md" <<EOF
  # \`$OU/$ACCOUNT_NAME\`

  <!-- BEGIN_TF_DOCS -->

  <!-- END_TF_DOCS -->
  EOF

  # backend.hcl
  cat > "$TARGET/backend.hcl" <<EOF
  bucket = "$STATE_BUCKET"
  EOF

  echo "✓ Account root files written to providers/aws/accounts/$OU/$ACCOUNT_NAME/"
  ```

- [ ] **Step 3: Verify the change**

  ```bash
  grep -n "backend.hcl\|STATE_BUCKET" scripts/create-aws-account.sh
  ```

  Expected: three hits — the `source config.sh` line (which defines `STATE_BUCKET`) and the new `cat > "$TARGET/backend.hcl"` line, plus the existing uses of `$STATE_BUCKET` in `main.tf` writes.

- [ ] **Step 4: Commit the two script changes**

  ```bash
  git add scripts/create-gcp-project.sh scripts/create-aws-account.sh
  git commit -m "feat(scripts): explicitly generate backend.hcl from STATE_BUCKET in both scaffold scripts"
  ```

  Expected: pre-commit hooks run (terraform fmt/validate skipped — no .tf files changed), commit succeeds.

---

## Task 3: Scaffold `tapshalkar-com-web` with the updated script

**Files:**
- Creates: `providers/gcp/projects/personal/tapshalkar-com-web/` (all files)
- Modifies: `Makefile`, `scripts/tf-all.sh`

- [ ] **Step 1: Run the scaffold script**

  ```bash
  ./scripts/create-gcp-project.sh personal tapshalkar-com-web
  ```

  Expected output ends with:
  ```
  ✓ Project scaffolded at: providers/gcp/projects/personal/tapshalkar-com-web/
  ✓ terraform.tfvars generated (review before applying)

  Next steps:
    1. Review and adjust if needed: ...
    2. Init, import, and apply: ...
  ```

- [ ] **Step 2: Verify all expected files exist**

  ```bash
  ls providers/gcp/projects/personal/tapshalkar-com-web/
  ```

  Expected files: `backend.hcl  backend.tf  main.tf  outputs.tf  terraform.tfvars  terraform.tfvars.example  variables.tf`

- [ ] **Step 3: Verify `backend.hcl` content**

  ```bash
  cat providers/gcp/projects/personal/tapshalkar-com-web/backend.hcl
  ```

  Expected:
  ```
  bucket = "tapshalkar-com-tfstate"
  ```

- [ ] **Step 4: Verify `backend.tf` prefix**

  ```bash
  cat providers/gcp/projects/personal/tapshalkar-com-web/backend.tf
  ```

  Expected:
  ```hcl
  terraform {
    backend "gcs" {
      # bucket is set via -backend-config or backend.hcl (gitignored)
      prefix = "gcp/projects/personal/tapshalkar-com-web"
    }
  }
  ```

- [ ] **Step 5: Verify `main.tf` uses the personal folder output**

  ```bash
  grep "folder_resource_name" providers/gcp/projects/personal/tapshalkar-com-web/main.tf
  ```

  Expected:
  ```
    folder_id                     = data.terraform_remote_state.gcp_org.outputs.personal_folder_resource_name
  ```

- [ ] **Step 6: Verify Makefile was patched**

  ```bash
  grep "gcp-personal-tapshalkar-com-web" Makefile
  ```

  Expected: at least two lines — one in `.PHONY` and one target definition.

---

## Task 4: Apply web-specific patches to `variables.tf`

**Files:**
- Modify: `providers/gcp/projects/personal/tapshalkar-com-web/variables.tf`

Three changes: add `storage.googleapis.com` to APIs, disable data access audit logs, fix the `env` label.

- [ ] **Step 1: Add `storage.googleapis.com` to the `enabled_apis` default**

  Find this block in `variables.tf`:
  ```hcl
    default = [
      "compute.googleapis.com",
      "iam.googleapis.com",
      "cloudbilling.googleapis.com",
      "billingbudgets.googleapis.com",
      "cloudresourcemanager.googleapis.com",
      "logging.googleapis.com",
      "monitoring.googleapis.com",
      "iamcredentials.googleapis.com",
    ]
  ```

  Replace with:
  ```hcl
    default = [
      "compute.googleapis.com",
      "iam.googleapis.com",
      "cloudbilling.googleapis.com",
      "billingbudgets.googleapis.com",
      "cloudresourcemanager.googleapis.com",
      "logging.googleapis.com",
      "monitoring.googleapis.com",
      "iamcredentials.googleapis.com",
      "storage.googleapis.com",
    ]
  ```

- [ ] **Step 2: Set `enable_data_access_audit_logs` default to `false`**

  Find:
  ```hcl
    default     = true
  ```
  (in the `enable_data_access_audit_logs` variable block)

  Replace with:
  ```hcl
    default     = false
  ```

- [ ] **Step 3: Fix the `labels` env default from `"personal"` to `"web"`**

  Find:
  ```hcl
    default = {
      env          = "personal"
      "managed-by" = "terraform"
    }
  ```

  Replace with:
  ```hcl
    default = {
      env          = "web"
      "managed-by" = "terraform"
    }
  ```

- [ ] **Step 4: Verify `terraform.tfvars` budget**

  ```bash
  grep "budget_amount" providers/gcp/projects/personal/tapshalkar-com-web/terraform.tfvars
  ```

  Expected: `budget_amount = 20`. The script sets this by default — no change needed.

- [ ] **Step 5: Run `terraform fmt` on the new project directory**

  ```bash
  cd providers/gcp/projects/personal/tapshalkar-com-web && terraform fmt && cd -
  ```

  Expected: no output (files already formatted) or the filename printed if spacing was adjusted.

- [ ] **Step 6: Commit all scaffolded files (excluding `terraform.tfvars`)**

  ```bash
  git add \
    providers/gcp/projects/personal/tapshalkar-com-web/backend.tf \
    providers/gcp/projects/personal/tapshalkar-com-web/backend.hcl \
    providers/gcp/projects/personal/tapshalkar-com-web/main.tf \
    providers/gcp/projects/personal/tapshalkar-com-web/outputs.tf \
    providers/gcp/projects/personal/tapshalkar-com-web/terraform.tfvars.example \
    providers/gcp/projects/personal/tapshalkar-com-web/variables.tf \
    Makefile \
    scripts/tf-all.sh
  git commit -m "feat(gcp): scaffold tapshalkar-com-web project with web-specific defaults"
  ```

  Expected: pre-commit hooks run terraform fmt + validate on the new `.tf` files, all pass, commit succeeds.

---

## Post-Commit: Apply the project (manual)

These steps require GCP credentials and are run manually after the commit is merged.

```bash
cd providers/gcp/projects/personal/tapshalkar-com-web
terraform init -backend-config="bucket=tapshalkar-com-tfstate"
terraform import module.baseline.google_project.this projects/tapshalkar-com-web
terraform plan
terraform apply
```
