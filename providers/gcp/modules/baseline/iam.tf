# Bind the personal admin account as project owner
resource "google_project_iam_member" "admin" {
  project = google_project.this.project_id
  role    = "roles/owner"
  member  = "user:${var.admin_user}"

  depends_on = [google_project_service.apis]
}
