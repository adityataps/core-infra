resource "google_project" "this" {
  project_id      = var.project_id
  name            = var.project_name
  billing_account = var.billing_account
  labels          = var.labels

  lifecycle {
    # Prevent accidental project deletion
    prevent_destroy = true
    # Ignore label drift from console edits. Note: this also means label changes
    # in tfvars will have no effect after initial apply. To enforce label changes,
    # remove ignore_changes, run terraform apply, then add it back.
    ignore_changes = [labels]
  }
}
