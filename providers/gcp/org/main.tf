data "google_organization" "this" {
  domain = var.domain
}

resource "google_folder" "folders" {
  for_each = local.folder_names

  display_name = each.value
  parent       = data.google_organization.this.name
}

resource "google_organization_iam_member" "admin" {
  for_each = toset(["roles/resourcemanager.organizationAdmin", "roles/resourcemanager.folderAdmin"])

  org_id = data.google_organization.this.org_id
  role   = each.value
  member = "user:${var.admin_user}"
}
