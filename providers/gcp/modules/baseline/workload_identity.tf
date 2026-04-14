# All resources in this file are conditional on var.github_repo being set

resource "google_service_account" "github_actions" {
  count = var.github_repo != null ? 1 : 0

  project      = google_project.this.project_id
  account_id   = "github-actions"
  display_name = "GitHub Actions"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation"

  depends_on = [google_project_service.apis]
}

# Grant the SA permissions needed to run terraform plan/apply.
# Note: iam.securityAdmin + resourcemanager.projectIamAdmin together allow the SA
# to set any IAM policy on this project (required for Terraform to manage IAM bindings).
# This is an accepted tradeoff for a Terraform-managed project SA — scoped to this
# single project only. Do not reuse this module for multi-project shared SAs.
resource "google_project_iam_member" "github_actions_roles" {
  for_each = var.github_repo != null ? toset([
    "roles/viewer",
    "roles/iam.securityAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/billing.projectManager",
    "roles/monitoring.editor",
    "roles/logging.configWriter",
  ]) : toset([])

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

resource "google_iam_workload_identity_pool" "github" {
  count = var.github_repo != null ? 1 : 0

  project                   = google_project.this.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions OIDC tokens"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.github_repo != null ? 1 : 0

  project                            = google_project.this.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions OIDC Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Only tokens from this specific repo are accepted
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_wif" {
  count = var.github_repo != null ? 1 : 0

  service_account_id = google_service_account.github_actions[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.repository/${var.github_repo}"
}
