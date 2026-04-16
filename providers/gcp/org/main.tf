data "google_organization" "this" {
  domain = var.domain
}

resource "google_folder" "personal" {
  display_name = "personal"
  parent       = data.google_organization.this.name
}

resource "google_folder" "certs" {
  display_name = "certs"
  parent       = data.google_organization.this.name
}

resource "google_organization_iam_member" "admin" {
  org_id = data.google_organization.this.org_id
  role   = "roles/resourcemanager.organizationAdmin"
  member = "user:${var.admin_user}"
}
