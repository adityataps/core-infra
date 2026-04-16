output "billing_account_id" {
  description = "Billing account ID used by this org. Consumed by other project roots via terraform_remote_state."
  value       = var.billing_account
}

output "project_id" {
  description = "The GCP project ID"
  value       = module.baseline.project_id
}

output "project_number" {
  description = "The GCP project number"
  value       = module.baseline.project_number
}

output "github_actions_service_account_email" {
  description = "Email of the GitHub Actions service account (set as GCP_SERVICE_ACCOUNT GitHub secret)"
  value       = module.baseline.github_actions_service_account_email
}

output "workload_identity_provider" {
  description = "WIF provider resource name (set as GCP_WORKLOAD_IDENTITY_PROVIDER GitHub secret)"
  value       = module.baseline.workload_identity_provider
}
