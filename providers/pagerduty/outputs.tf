output "integration_key" {
  value       = pagerduty_service_integration.gcp.integration_key
  description = "PagerDuty routing key for the GCP Monitoring service integration. Consumed automatically via terraform_remote_state in providers/gcp/projects/personal/tapshalkar-com."
  sensitive   = true
}
