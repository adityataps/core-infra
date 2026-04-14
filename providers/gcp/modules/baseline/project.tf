resource "google_project" "this" {
  project_id      = var.project_id
  name            = var.project_name
  billing_account = var.billing_account
  labels          = var.labels

  lifecycle {
    # Prevent accidental project deletion
    prevent_destroy = true
    # Allow labels to be updated without replacing
    ignore_changes = [labels]
  }
}
