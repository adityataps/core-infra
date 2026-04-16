data "google_organization" "this" {
  domain = var.domain
}

data "google_billing_account" "this" {
  open = true
}

resource "google_folder" "management" {
  display_name = "management"
  parent       = data.google_organization.this.name
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
  for_each = toset(["roles/resourcemanager.organizationAdmin", "roles/resourcemanager.folderAdmin"])

  org_id = data.google_organization.this.org_id
  role   = each.value
  member = "user:${var.admin_user}"
}
