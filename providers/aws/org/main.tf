data "aws_organizations_organization" "this" {}

resource "aws_organizations_organizational_unit" "personal" {
  name      = "personal"
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "certs" {
  name      = "certs"
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "projects" {
  name      = "projects"
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "certs_1" {
  name      = var.certs_1_account_name
  email     = var.certs_1_account_email
  parent_id = aws_organizations_organizational_unit.certs.id

  lifecycle {
    # iam_user_access_to_billing and role_name are set at account creation and
    # not reliably readable via API — ignoring prevents spurious diffs on import.
    ignore_changes = [iam_user_access_to_billing, role_name]
  }
}

resource "aws_organizations_account" "certs_2" {
  name      = var.certs_2_account_name
  email     = var.certs_2_account_email
  parent_id = aws_organizations_organizational_unit.certs.id

  lifecycle {
    ignore_changes = [iam_user_access_to_billing, role_name]
  }
}

resource "aws_organizations_account" "side_project" {
  name      = var.side_project_account_name
  email     = var.side_project_account_email
  parent_id = aws_organizations_organizational_unit.projects.id

  lifecycle {
    ignore_changes = [iam_user_access_to_billing, role_name]
  }
}

resource "aws_organizations_account" "personal" {
  name              = var.personal_account_name
  email             = var.personal_account_email
  parent_id         = aws_organizations_organizational_unit.personal.id
  close_on_deletion = true
}
