resource "google_monitoring_notification_channel" "budget_email" {
  project      = google_project.this.project_id
  display_name = "Budget Alert — ${var.project_id}"
  type         = "email"

  labels = {
    email_address = var.admin_user
  }

  depends_on = [google_project_service.apis]
}

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

resource "google_monitoring_notification_channel" "budget_pagerduty" {
  count        = var.pagerduty_budget_email != null ? 1 : 0
  project      = google_project.this.project_id
  display_name = "PagerDuty Budget Email — ${var.project_id}"
  type         = "email"

  labels = {
    email_address = var.pagerduty_budget_email
  }

  depends_on = [google_project_service.apis]
}

resource "google_billing_budget" "project" {
  billing_account = var.billing_account
  display_name    = "${var.project_id}-monthly-budget"

  budget_filter {
    projects = ["projects/${google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(floor(var.budget_amount))
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    # Billing accepts email channels; use a dedicated PagerDuty email integration.
    monitoring_notification_channels = concat(
      [google_monitoring_notification_channel.budget_email.id],
      google_monitoring_notification_channel.budget_pagerduty[*].id,
    )
    disable_default_iam_recipients = true
  }
}
