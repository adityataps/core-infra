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
