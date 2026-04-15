# PagerDuty Integration Design

**Date:** 2026-04-15
**Scope:** Route GCP budget and monitoring alerts to PagerDuty via a standalone Terraform root module

---

## Overview

Add PagerDuty alert routing to core-infra using a standalone `providers/pagerduty/` Terraform root with its own GCS-backed state. The GCP baseline module gains an optional `pagerduty_integration_key` variable — when set, it creates a PagerDuty notification channel and wires it into budget alerts and a monitoring alert policy stub. Cross-stack wiring is manual: the integration key is output from the PagerDuty root and pasted into the GCP project's `terraform.tfvars`.

---

## Repo Structure

```
providers/pagerduty/
  main.tf                     # provider, escalation policy, service, integration
  variables.tf                # api_token, escalation_policy_id
  outputs.tf                  # integration_key
  backend.tf                  # GCS backend, prefix = "pagerduty"
  terraform.tfvars            # gitignored
  terraform.tfvars.example
```

**Modified:**
```
providers/gcp/modules/baseline/
  variables.tf                # add pagerduty_integration_key (optional, sensitive)
  budgets.tf                  # wire PagerDuty channel into budget all_updates_rule
  monitoring.tf               # NEW: disabled stub alert policy wired to both channels

providers/gcp/projects/adits-gcp/
  variables.tf                # add pagerduty_integration_key passthrough
  main.tf                     # pass variable to baseline module
  terraform.tfvars.example    # document new variable

CLAUDE.md                     # document cross-stack wiring steps
```

---

## Section 1 — PagerDuty Root (`providers/pagerduty/`)

### Resources

**`pagerduty_escalation_policy`** — imports the existing escalation policy from the PagerDuty account. No recreation. Future changes (e.g. adding AWS alert routing) happen in code from this point forward.

**`pagerduty_service`** — "GCP Monitoring" service linked to the escalation policy. Represents all GCP alerts as a single service (budget alerts now, metric alerts later). `auto_resolve_timeout = 86400` (24h — standard for infrastructure alerts).

**`pagerduty_service_integration`** — uses the native **Google Cloud Platform** PagerDuty vendor (`name = "Google Cloud Platform"` looked up via `data "pagerduty_vendor"`). Formats GCP alert payloads correctly in the PagerDuty UI. Outputs the `integration_key`.

### Auth

`api_token` variable sourced from gitignored `terraform.tfvars`. Generated from PagerDuty → My Profile → API Access Keys → Create New API Key.

### Variables

| Variable | Type | Description |
|---|---|---|
| `api_token` | string (sensitive) | PagerDuty API token |
| `escalation_policy_id` | string | ID of the existing escalation policy to import |

### Outputs

| Output | Description |
|---|---|
| `integration_key` | PagerDuty routing key — paste into GCP project tfvars |

### State

GCS backend, `prefix = "pagerduty"` in the shared state bucket. Applied independently from GCP.

---

## Section 2 — GCP Baseline Changes

### `variables.tf`

New optional variable:
```hcl
variable "pagerduty_integration_key" {
  type        = string
  description = "PagerDuty integration key for GCP monitoring alerts. Null disables PagerDuty routing."
  default     = null
  sensitive   = true
}
```

### `budgets.tf`

New conditional notification channel:
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

The `all_updates_rule` in `google_billing_budget` is updated to include both channels:
```hcl
monitoring_notification_channels = compact([
  google_monitoring_notification_channel.budget_email.id,
  length(google_monitoring_notification_channel.pagerduty) > 0
    ? google_monitoring_notification_channel.pagerduty[0].id
    : null
])
```

### `monitoring.tf` (new file)

A disabled stub `google_monitoring_alert_policy` that pre-wires both notification channels. Adding real alert conditions later is a one-line change per alert. Disabled by default (`enabled = false`) so it creates no noise until real conditions are added.

```hcl
resource "google_monitoring_alert_policy" "default" {
  project      = google_project.this.project_id
  display_name = "${var.project_id} — Default Alert Policy"
  combiner     = "OR"
  enabled      = false

  # Add alert conditions here as needed, e.g.:
  # conditions { ... }

  notification_channels = compact([
    google_monitoring_notification_channel.budget_email.id,
    length(google_monitoring_notification_channel.pagerduty) > 0
      ? google_monitoring_notification_channel.pagerduty[0].id
      : null
  ])

  depends_on = [google_project_service.apis]
}
```

---

## Section 3 — Cross-Stack Wiring

After applying `providers/pagerduty/`:
```bash
cd providers/pagerduty
terraform output integration_key
```

Paste the value into `providers/gcp/projects/adits-gcp/terraform.tfvars`:
```hcl
pagerduty_integration_key = "abc123..."
```

Then apply the GCP project:
```bash
cd providers/gcp/projects/adits-gcp
terraform apply
```

The `pagerduty_integration_key` is `sensitive = true` in all variable declarations — Terraform redacts it from plan/apply output and CLI logs. The value lives only in the gitignored `terraform.tfvars` and in GCS state (encrypted at rest).

---

## Extensibility

- **Additional GCP projects:** Pass `pagerduty_integration_key` in each project's `terraform.tfvars`. The same PagerDuty service handles all projects.
- **AWS alerts:** Add an `aws_cloudwatch_metric_alarm` or SNS → PagerDuty integration to a future `providers/aws/` root, using the same escalation policy already managed in `providers/pagerduty/`.
- **Real monitoring conditions:** Enable `google_monitoring_alert_policy.default` and add `conditions` blocks in `monitoring.tf` — no notification channel wiring required, already in place.
- **Multiple services:** Add more `pagerduty_service` resources (e.g. one per severity level) and expose their keys as additional outputs.
