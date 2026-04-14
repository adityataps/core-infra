output "project_id" {
  description = "The GCP project ID"
  value       = google_project.this.project_id
}

output "project_number" {
  description = "The GCP project number"
  value       = google_project.this.number
}

output "github_actions_service_account_email" {
  description = "Email of the GitHub Actions service account (null if github_repo not set)"
  value       = length(google_service_account.github_actions) > 0 ? google_service_account.github_actions[0].email : null
}

output "workload_identity_provider" {
  description = "Full WIF provider resource name for use in GitHub Actions (null if github_repo not set)"
  value       = length(google_iam_workload_identity_pool_provider.github) > 0 ? google_iam_workload_identity_pool_provider.github[0].name : null
}
