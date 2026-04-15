resource "google_monitoring_alert_policy" "default" {
  project      = google_project.this.project_id
  display_name = "${var.project_id} — Default Alert Policy"
  combiner     = "OR"
  enabled      = false

  conditions {
    display_name = "Placeholder condition"
    condition_threshold {
      filter          = "resource.type=\"global\""
      comparison      = "COMPARISON_EQ"
      threshold_value = 1
      duration        = "0s"
    }
  }

  # Add additional alert conditions here as needed, e.g.:
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
