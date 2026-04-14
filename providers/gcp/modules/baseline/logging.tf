# Enable audit logs (admin activity and data access) for all services.
# ADMIN_READ is free; DATA_READ and DATA_WRITE are billable beyond 50 GiB/month.
resource "google_project_iam_audit_config" "default" {
  project = google_project.this.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  dynamic "audit_log_config" {
    for_each = var.enable_data_access_audit_logs ? ["DATA_READ", "DATA_WRITE"] : []
    content {
      log_type = audit_log_config.value
    }
  }

  depends_on = [google_project_service.apis]
}
