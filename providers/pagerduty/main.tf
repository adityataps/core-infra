# Import the existing escalation policy from PagerDuty before first apply.
# Find the ID in the PagerDuty URL: Settings → Escalation Policies → click policy → copy ID from URL path.
# Run: terraform import pagerduty_escalation_policy.default <ESCALATION_POLICY_ID>
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
  name = "Google Cloud Monitoring"
}

resource "pagerduty_service" "gcp_monitoring" {
  name                    = "GCP Monitoring"
  escalation_policy       = pagerduty_escalation_policy.default.id
  auto_resolve_timeout    = 86400
  acknowledgement_timeout = 0
  alert_creation          = "create_alerts_and_incidents"
}

resource "pagerduty_service_integration" "gcp" {
  name    = data.pagerduty_vendor.gcp.name
  service = pagerduty_service.gcp_monitoring.id
  vendor  = data.pagerduty_vendor.gcp.id
}
