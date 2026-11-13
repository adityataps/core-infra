output "gcp_integration_key" {
  value       = pagerduty_service_integration.gcp.integration_key
  description = "PagerDuty routing key for the GCP Monitoring service integration. Consumed automatically via terraform_remote_state in GCP project roots."
  sensitive   = true
}

output "gcp_budget_integration_email" {
  value       = pagerduty_service_integration.gcp_budgets.integration_email
  description = "Dedicated PagerDuty email integration for GCP Billing Budgets. Consumed by GCP project roots."
  sensitive   = true
}

output "aws_integration_key" {
  value       = pagerduty_service_integration.aws_cloudwatch.integration_key
  description = "PagerDuty Amazon CloudWatch service integration key. Used as the SNS HTTPS endpoint via https://events.pagerduty.com/integration/<key>/enqueue — this endpoint handles SNS SubscriptionConfirmation automatically."
  sensitive   = true
}

output "aws_budget_integration_key" {
  value       = pagerduty_service_integration.aws_budgets.integration_key
  description = "PagerDuty Events API v2 routing key for the AWS budget SNS forwarder."
  sensitive   = true
}
