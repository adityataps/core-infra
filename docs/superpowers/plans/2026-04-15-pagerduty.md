# PagerDuty Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a standalone `providers/pagerduty/` Terraform root that creates a GCP Monitoring service integration in PagerDuty, then wire its integration key into the GCP baseline module to route budget alerts (and a stub monitoring alert policy) to PagerDuty.

**Architecture:** Two independently-applied roots — `providers/pagerduty/` outputs an integration key; `providers/gcp/projects/adits-gcp/` consumes it via a gitignored `terraform.tfvars`. No `terraform_remote_state` data source — the key is pasted manually. The GCP baseline gains an optional `pagerduty_integration_key` variable (null = no PagerDuty, set = creates channel and wires it in).

**Tech Stack:** Terraform >= 1.5, PagerDuty provider `PagerDuty/PagerDuty ~> 3.0`, Google provider `hashicorp/google ~> 5.0`, GCS remote state.

---

## File Map

**Create:**
- `providers/pagerduty/backend.tf` — GCS remote state, prefix `"pagerduty"`
- `providers/pagerduty/versions.tf` — required_version + PagerDuty provider pin
- `providers/pagerduty/variables.tf` — `api_token`, `escalation_policy_id`
- `providers/pagerduty/main.tf` — escalation policy import, pagerduty_service, pagerduty_service_integration
- `providers/pagerduty/outputs.tf` — `integration_key` (sensitive)
- `providers/pagerduty/terraform.tfvars.example` — documented placeholder values
- `providers/gcp/modules/baseline/monitoring.tf` — disabled stub alert policy

**Modify:**
- `providers/gcp/modules/baseline/variables.tf` — add `pagerduty_integration_key` (optional, sensitive)
- `providers/gcp/modules/baseline/budgets.tf` — add conditional PagerDuty channel + update `all_updates_rule`
- `providers/gcp/projects/adits-gcp/variables.tf` — add `pagerduty_integration_key` passthrough
- `providers/gcp/projects/adits-gcp/main.tf` — pass new variable to baseline module
- `providers/gcp/projects/adits-gcp/terraform.tfvars.example` — document new variable
- `CLAUDE.md` — document cross-stack wiring steps

---

### Task 1: PagerDuty Root Module

**Files:**
- Create: `providers/pagerduty/backend.tf`
- Create: `providers/pagerduty/versions.tf`
- Create: `providers/pagerduty/variables.tf`
- Create: `providers/pagerduty/main.tf`
- Create: `providers/pagerduty/outputs.tf`
- Create: `providers/pagerduty/terraform.tfvars.example`

- [ ] **Step 1: Create `providers/pagerduty/backend.tf`**

```hcl
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "pagerduty"
  }
}
```

- [ ] **Step 2: Create `providers/pagerduty/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    pagerduty = {
      source  = "PagerDuty/PagerDuty"
      version = "~> 3.0"
    }
  }
}

provider "pagerduty" {
  token = var.api_token
}
```

- [ ] **Step 3: Create `providers/pagerduty/variables.tf`**

```hcl
variable "api_token" {
  type        = string
  description = "PagerDuty API token. Generate from PagerDuty → My Profile → API Access Keys → Create New API Key."
  sensitive   = true
}

variable "escalation_policy_id" {
  type        = string
  description = "ID of the existing PagerDuty escalation policy to import. Find it in the PagerDuty URL when viewing the policy: /escalation_policies/<ID>"
}
```

- [ ] **Step 4: Create `providers/pagerduty/main.tf`**

```hcl
# Import the existing escalation policy — run:
#   terraform import pagerduty_escalation_policy.default <ESCALATION_POLICY_ID>
resource "pagerduty_escalation_policy" "default" {
  name      = "Default"
  num_loops = 2

  rule {
    escalation_delay_in_minutes = 30
    target {
      type = "user_reference"
      id   = data.pagerduty_user.admin.id
    }
  }
}

data "pagerduty_user" "admin" {
  email = var.admin_email
}

data "pagerduty_vendor" "gcp" {
  name = "Google Cloud Platform"
}

resource "pagerduty_service" "gcp_monitoring" {
  name                    = "GCP Monitoring"
  escalation_policy       = pagerduty_escalation_policy.default.id
  auto_resolve_timeout    = 86400
  acknowledgement_timeout = "null"
  alert_creation          = "create_alerts_and_incidents"
}

resource "pagerduty_service_integration" "gcp" {
  name    = data.pagerduty_vendor.gcp.name
  service = pagerduty_service.gcp_monitoring.id
  vendor  = data.pagerduty_vendor.gcp.id
}
```

**Note:** The `pagerduty_escalation_policy` resource will be imported from the existing policy (not recreated) in Task 6. The resource block above must match the existing policy's current configuration — adjust `name`, `num_loops`, `escalation_delay_in_minutes`, and `target.id` to match what's in your PagerDuty account before importing. Add `variable "admin_email"` to variables.tf in the next step.

- [ ] **Step 5: Update `providers/pagerduty/variables.tf` — add `admin_email`**

```hcl
variable "api_token" {
  type        = string
  description = "PagerDuty API token. Generate from PagerDuty → My Profile → API Access Keys → Create New API Key."
  sensitive   = true
}

variable "escalation_policy_id" {
  type        = string
  description = "ID of the existing PagerDuty escalation policy to import. Find it in the PagerDuty URL when viewing the policy: /escalation_policies/<ID>"
}

variable "admin_email" {
  type        = string
  description = "Email address of the PagerDuty admin user to target in the escalation policy."
}
```

- [ ] **Step 6: Create `providers/pagerduty/outputs.tf`**

```hcl
output "integration_key" {
  value       = pagerduty_service_integration.gcp.integration_key
  description = "PagerDuty routing key for the GCP Monitoring service integration. Paste into providers/gcp/projects/adits-gcp/terraform.tfvars as pagerduty_integration_key."
  sensitive   = true
}
```

- [ ] **Step 7: Create `providers/pagerduty/terraform.tfvars.example`**

```hcl
api_token            = "your-pagerduty-api-token"
escalation_policy_id = "PXXXXXX"
admin_email          = "you@example.com"
```

- [ ] **Step 8: Run `terraform init` and `terraform validate`**

```bash
cd providers/pagerduty
terraform init -backend-config="bucket=<YOUR_STATE_BUCKET_NAME>"
terraform validate
```

Expected: `Success! The configuration is valid.`

If `terraform init` fails with "bucket not found", confirm your GCS state bucket name from `bootstrap/` outputs and pass it via `-backend-config`.

- [ ] **Step 9: Commit**

```bash
git add providers/pagerduty/
git commit -m "feat: add providers/pagerduty root module"
```

---

### Task 2: GCP Baseline — `pagerduty_integration_key` variable + notification channel

**Files:**
- Modify: `providers/gcp/modules/baseline/variables.tf`
- Modify: `providers/gcp/modules/baseline/budgets.tf`

- [ ] **Step 1: Add `pagerduty_integration_key` to `providers/gcp/modules/baseline/variables.tf`**

Append to the end of the file:

```hcl
variable "pagerduty_integration_key" {
  type        = string
  description = "PagerDuty integration key for GCP monitoring alerts. Null disables PagerDuty routing."
  default     = null
  sensitive   = true
}
```

- [ ] **Step 2: Add PagerDuty notification channel in `providers/gcp/modules/baseline/budgets.tf`**

Add after the existing `google_monitoring_notification_channel.budget_email` resource block:

```hcl
resource "google_monitoring_notification_channel" "pagerduty" {
  count        = var.pagerduty_integration_key != null ? 1 : 0
  project      = google_project.this.project_id
  display_name = "PagerDuty — ${var.project_id}"
  type         = "pagerduty"
  labels = {
    service_key = var.pagerduty_integration_key
  }
  depends_on = [google_project_service.apis]
}
```

- [ ] **Step 3: Update `all_updates_rule` in `google_billing_budget.project` to include PagerDuty channel**

In `providers/gcp/modules/baseline/budgets.tf`, replace the `all_updates_rule` block:

```hcl
  all_updates_rule {
    monitoring_notification_channels = compact([
      google_monitoring_notification_channel.budget_email.id,
      length(google_monitoring_notification_channel.pagerduty) > 0
        ? google_monitoring_notification_channel.pagerduty[0].id
        : null
    ])
    disable_default_iam_recipients = true
  }
```

- [ ] **Step 4: Run `terraform validate` in the adits-gcp project dir (tests the module)**

```bash
cd providers/gcp/projects/adits-gcp
terraform validate
```

Expected: `Success! The configuration is valid.`

This will fail until Task 4 wires the variable through — proceed to Task 3 first if working sequentially, then run validate after Task 4.

- [ ] **Step 5: Commit**

```bash
git add providers/gcp/modules/baseline/variables.tf providers/gcp/modules/baseline/budgets.tf
git commit -m "feat(baseline): add optional pagerduty_integration_key variable and notification channel"
```

---

### Task 3: GCP Baseline — `monitoring.tf` stub alert policy

**Files:**
- Create: `providers/gcp/modules/baseline/monitoring.tf`

- [ ] **Step 1: Create `providers/gcp/modules/baseline/monitoring.tf`**

```hcl
resource "google_monitoring_alert_policy" "default" {
  project      = google_project.this.project_id
  display_name = "${var.project_id} — Default Alert Policy"
  combiner     = "OR"
  enabled      = false

  # Add alert conditions here as needed, e.g.:
  # conditions {
  #   display_name = "CPU utilization high"
  #   condition_threshold {
  #     filter          = "resource.type=\"gce_instance\""
  #     comparison      = "COMPARISON_GT"
  #     threshold_value = 0.9
  #     duration        = "60s"
  #   }
  # }

  notification_channels = compact([
    google_monitoring_notification_channel.budget_email.id,
    length(google_monitoring_notification_channel.pagerduty) > 0
      ? google_monitoring_notification_channel.pagerduty[0].id
      : null
  ])

  depends_on = [google_project_service.apis]
}
```

- [ ] **Step 2: Run `terraform validate` in the baseline module (via a project dir)**

```bash
cd providers/gcp/projects/adits-gcp
terraform validate
```

Expected: `Success! The configuration is valid.`

(Requires Task 4 to be complete first — the variable must be wired through before validate succeeds.)

- [ ] **Step 3: Commit**

```bash
git add providers/gcp/modules/baseline/monitoring.tf
git commit -m "feat(baseline): add disabled stub monitoring alert policy pre-wired to notification channels"
```

---

### Task 4: adits-gcp — wire `pagerduty_integration_key` through project layer

**Files:**
- Modify: `providers/gcp/projects/adits-gcp/variables.tf`
- Modify: `providers/gcp/projects/adits-gcp/main.tf`
- Modify: `providers/gcp/projects/adits-gcp/terraform.tfvars.example`

- [ ] **Step 1: Add `pagerduty_integration_key` to `providers/gcp/projects/adits-gcp/variables.tf`**

Append to the end of the file:

```hcl
variable "pagerduty_integration_key" {
  type        = string
  description = "PagerDuty integration key for GCP monitoring alerts. Null disables PagerDuty routing."
  default     = null
  sensitive   = true
}
```

- [ ] **Step 2: Pass `pagerduty_integration_key` to baseline module in `providers/gcp/projects/adits-gcp/main.tf`**

In the `module "baseline"` block, add after `enable_data_access_audit_logs`:

```hcl
  pagerduty_integration_key     = var.pagerduty_integration_key
```

The full module block becomes:

```hcl
module "baseline" {
  source = "../../modules/baseline"

  project_id                    = var.project_id
  project_name                  = var.project_name
  billing_account               = var.billing_account
  admin_user                    = var.admin_user
  region                        = var.region
  budget_amount                 = var.budget_amount
  budget_thresholds             = var.budget_thresholds
  labels                        = var.labels
  enabled_apis                  = var.enabled_apis
  github_repo                   = var.github_repo
  enable_data_access_audit_logs = var.enable_data_access_audit_logs
  pagerduty_integration_key     = var.pagerduty_integration_key
}
```

- [ ] **Step 3: Document new variable in `providers/gcp/projects/adits-gcp/terraform.tfvars.example`**

Append to the end of the file:

```hcl
# pagerduty_integration_key = "abc123..."  # output from providers/pagerduty: terraform output integration_key
```

- [ ] **Step 4: Run `terraform validate`**

```bash
cd providers/gcp/projects/adits-gcp
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Run `terraform plan` (without PagerDuty key — verify no changes to existing resources)**

```bash
cd providers/gcp/projects/adits-gcp
terraform plan
```

Expected: Plan shows one new resource (`google_monitoring_alert_policy.default` in disabled state). No changes to existing budget, notification channel, or other resources. The PagerDuty notification channel should NOT appear since `pagerduty_integration_key` is null.

- [ ] **Step 6: Commit**

```bash
git add providers/gcp/projects/adits-gcp/variables.tf \
        providers/gcp/projects/adits-gcp/main.tf \
        providers/gcp/projects/adits-gcp/terraform.tfvars.example
git commit -m "feat(adits-gcp): wire pagerduty_integration_key through to baseline module"
```

---

### Task 5: Update CLAUDE.md — cross-stack wiring steps

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add PagerDuty cross-stack wiring section to `CLAUDE.md`**

Add the following section after the `## GitHub Actions Secrets` section:

```markdown
## PagerDuty Integration

The PagerDuty root (`providers/pagerduty/`) is applied independently from GCP. After making changes to PagerDuty resources, apply that root first, then copy the integration key to the GCP project tfvars and apply GCP.

### First-time setup

1. Get the existing escalation policy ID from PagerDuty (Settings → Escalation Policies → click the policy → copy the ID from the URL: `/escalation_policies/<ID>`)
2. Fill in `providers/pagerduty/terraform.tfvars` (gitignored):
   ```hcl
   api_token            = "your-pagerduty-api-token"
   escalation_policy_id = "PXXXXXX"
   admin_email          = "you@example.com"
   ```
3. Initialize and import the existing escalation policy:
   ```bash
   cd providers/pagerduty
   terraform init -backend-config="bucket=<YOUR_STATE_BUCKET_NAME>"
   terraform import pagerduty_escalation_policy.default <ESCALATION_POLICY_ID>
   ```
4. Update the `pagerduty_escalation_policy.default` resource block in `providers/pagerduty/main.tf` to match the imported state (run `terraform show` after import to see current values)
5. Apply:
   ```bash
   terraform apply
   ```
6. Copy the integration key to the GCP project:
   ```bash
   terraform output integration_key
   ```
   Paste the value into `providers/gcp/projects/adits-gcp/terraform.tfvars`:
   ```hcl
   pagerduty_integration_key = "abc123..."
   ```
7. Apply the GCP project:
   ```bash
   cd providers/gcp/projects/adits-gcp
   terraform apply
   ```

### Adding PagerDuty to another GCP project

Pass `pagerduty_integration_key` in that project's `terraform.tfvars` — the same PagerDuty service handles all GCP projects.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document PagerDuty cross-stack wiring steps in CLAUDE.md"
```

---

### Task 6: Manual — Apply PagerDuty root and wire integration key to GCP

This task is performed manually. It cannot be automated because it requires PagerDuty credentials and reading the imported state to reconcile the escalation policy resource definition.

- [ ] **Step 1: Create `providers/pagerduty/terraform.tfvars` (gitignored)**

```hcl
api_token            = "<YOUR_PAGERDUTY_API_TOKEN>"
escalation_policy_id = "<YOUR_ESCALATION_POLICY_ID>"
admin_email          = "<YOUR_PAGERDUTY_EMAIL>"
```

Get the API token from PagerDuty → My Profile → API Access Keys → Create New API Key.

Get the escalation policy ID from PagerDuty → Services → Escalation Policies → click the policy → copy the ID from the URL path: `/escalation_policies/PXXXXXX`.

- [ ] **Step 2: Initialize and import the escalation policy**

```bash
cd providers/pagerduty
terraform init -backend-config="bucket=<YOUR_STATE_BUCKET_NAME>"
terraform import pagerduty_escalation_policy.default <ESCALATION_POLICY_ID>
```

Expected: `Import successful! The resources that were imported are shown above.`

- [ ] **Step 3: Reconcile escalation policy resource definition**

```bash
terraform show
```

Read the current state of `pagerduty_escalation_policy.default`. Update `providers/pagerduty/main.tf` to match: `name`, `num_loops`, `escalation_delay_in_minutes`, and all `rule` + `target` blocks must match exactly.

- [ ] **Step 4: Verify plan shows no changes to escalation policy**

```bash
terraform plan
```

Expected output: The `pagerduty_escalation_policy.default` resource shows no changes (already matches imported state). Two resources will be created: `pagerduty_service.gcp_monitoring` and `pagerduty_service_integration.gcp`.

- [ ] **Step 5: Apply**

```bash
terraform apply
```

Expected: Creates `pagerduty_service.gcp_monitoring` and `pagerduty_service_integration.gcp`. The PagerDuty UI should show a new "GCP Monitoring" service under Services.

- [ ] **Step 6: Copy integration key to GCP project tfvars**

```bash
terraform output integration_key
```

Paste the output value into `providers/gcp/projects/adits-gcp/terraform.tfvars`:

```hcl
pagerduty_integration_key = "<OUTPUT_VALUE>"
```

- [ ] **Step 7: Apply GCP project and verify**

```bash
cd providers/gcp/projects/adits-gcp
terraform plan
```

Expected: Two new resources:
- `module.baseline.google_monitoring_notification_channel.pagerduty[0]` — the PagerDuty channel
- `module.baseline.google_monitoring_alert_policy.default` — the disabled stub alert policy

The existing `google_billing_budget.project` will show an in-place update: `monitoring_notification_channels` gains the PagerDuty channel ID.

```bash
terraform apply
```

Expected: Apply complete with 2 resources added, 1 resource changed.

- [ ] **Step 8: Verify in GCP Console**

Navigate to GCP Console → Monitoring → Alerting → Notification Channels. Confirm "PagerDuty — adits-gcp" channel appears.

Navigate to GCP Console → Billing → Budgets & Alerts → click the project budget. Confirm the PagerDuty channel is listed under notification settings.

---

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| `providers/pagerduty/` with main.tf, variables.tf, outputs.tf, backend.tf, tfvars.example | Task 1 |
| `pagerduty_escalation_policy` import | Task 1 + Task 6 |
| `pagerduty_service` with auto_resolve_timeout = 86400 | Task 1 |
| `pagerduty_service_integration` with GCP vendor | Task 1 |
| `api_token` from gitignored tfvars | Task 1 + Task 6 |
| GCS backend prefix = "pagerduty" | Task 1 |
| `pagerduty_integration_key` optional sensitive variable in baseline | Task 2 |
| `google_monitoring_notification_channel.pagerduty` count-based | Task 2 |
| `compact([...])` pattern in `all_updates_rule` | Task 2 |
| `monitoring.tf` disabled stub alert policy | Task 3 |
| `compact([...])` pattern in alert policy notification_channels | Task 3 |
| adits-gcp variables.tf + main.tf + tfvars.example wiring | Task 4 |
| CLAUDE.md cross-stack wiring docs | Task 5 |
| Manual apply flow documented | Task 6 |

All spec requirements covered.

**Placeholder scan:** No TBD/TODO items — all code blocks are complete and explicit.

**Type consistency:** `pagerduty_integration_key` is `string` (nullable via `default = null`) in all three layers (baseline variables.tf, adits-gcp variables.tf, module call). The `compact([...])` pattern used identically in both `budgets.tf` and `monitoring.tf`. The `length(...) > 0 ? ...[0].id : null` pattern matches the existing `outputs.tf` convention in this repo.
