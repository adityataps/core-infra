resource "google_monitoring_alert_policy" "default" {
  project      = google_project.this.project_id
  display_name = "${var.project_id} — Default Alert Policy"
  combiner     = "OR"
  enabled      = false

  # The GCP provider requires at least one conditions block. This stub condition
  # is intentionally inert (equality check that never triggers). Replace with
  # real conditions to activate monitoring, e.g. CPU or memory thresholds.
  conditions {
    display_name = "Stub — replace with real condition"
    condition_threshold {
      filter          = "resource.type=\"global\""
      comparison      = "COMPARISON_EQ"
      threshold_value = 0
      duration        = "0s"
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
