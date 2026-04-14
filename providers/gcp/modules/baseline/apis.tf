resource "google_project_service" "apis" {
  for_each = toset(var.enabled_apis)

  project = google_project.this.project_id
  service = each.value

  # Don't disable APIs on destroy — other resources may depend on them
  disable_on_destroy         = false
  disable_dependent_services = false
}
