output "integration_key" {
  value       = pagerduty_service_integration.gcp.integration_key
  description = "PagerDuty routing key for the GCP Monitoring service integration. Paste into providers/gcp/projects/adits-gcp/terraform.tfvars as pagerduty_integration_key."
  sensitive   = true
}
