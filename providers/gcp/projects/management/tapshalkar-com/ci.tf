# The management service account plans all CI roots against the shared bucket.
# Plans need to create/delete lock objects, even though they do not write state.
# Keep this grant here so other projects using the baseline gain no bucket access.
resource "google_storage_bucket_iam_member" "github_actions_state_locks" {
  bucket = "tapshalkar-com-tfstate"
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.baseline.github_actions_service_account_email}"

  condition {
    title       = "terraform_ci_state_locks"
    description = "Allow Terraform plans to acquire and release state locks only."
    expression  = "resource.name.startsWith('projects/_/buckets/tapshalkar-com-tfstate/objects/') && resource.name.endsWith('.tflock')"
  }
}
