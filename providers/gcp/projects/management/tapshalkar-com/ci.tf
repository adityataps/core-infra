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

# CI also plans the organization root, which lives above this service account's
# project. Browser permits organization/folder discovery, without resource writes.
resource "google_organization_iam_member" "github_actions_browser" {
  org_id = data.terraform_remote_state.gcp_org.outputs.org_id
  role   = "roles/browser"
  member = "serviceAccount:${module.baseline.github_actions_service_account_email}"
}

resource "google_organization_iam_member" "github_actions_org_iam_viewer" {
  org_id = data.terraform_remote_state.gcp_org.outputs.org_id
  role   = "roles/iam.securityReviewer"
  member = "serviceAccount:${module.baseline.github_actions_service_account_email}"
}

# The management identity refreshes resources in each managed project; each
# project's own GitHub Actions identity keeps its existing separate permissions.
resource "google_project_iam_member" "github_actions_project_viewer" {
  for_each = toset([
    "tapshalkar-com-personal",
    "tapshalkar-com-sandbox",
    "tapshalkar-com-web",
  ])

  project = each.value
  role    = "roles/viewer"
  member  = "serviceAccount:${module.baseline.github_actions_service_account_email}"
}

resource "google_billing_account_iam_member" "github_actions_budget_viewer" {
  billing_account_id = var.billing_account
  role               = "roles/billing.viewer"
  member             = "serviceAccount:${module.baseline.github_actions_service_account_email}"
}
