resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  aws_service_access_principals = [
    "sso.amazonaws.com",
  ]
}

# ── IAM Identity Center ───────────────────────────────────────────────────────

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

resource "aws_identitystore_user" "aditya" {
  identity_store_id = local.identity_store_id

  display_name = "Aditya Tapshalkar"
  user_name    = "aditya@tapshalkar.com"

  name {
    given_name  = "Aditya"
    family_name = "Tapshalkar"
  }

  emails {
    value   = "aditya@tapshalkar.com"
    primary = true
  }
}

# ── Admin permission set ──────────────────────────────────────────────────────

resource "aws_ssoadmin_permission_set" "admin" {
  name         = "AdministratorAccess"
  instance_arn = local.sso_instance_arn
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ── Assign admin to all accounts ──────────────────────────────────────────────

resource "aws_ssoadmin_account_assignment" "aditya_admin" {
  for_each = toset(aws_organizations_organization.this.accounts[*].id)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn

  principal_type = "USER"
  principal_id   = aws_identitystore_user.aditya.user_id

  target_type = "AWS_ACCOUNT"
  target_id   = each.value
}

resource "aws_organizations_organizational_unit" "personal" {
  name      = "personal"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "certs" {
  name      = "certs"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "projects" {
  name      = "projects"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "management" {
  name      = "management"
  parent_id = aws_organizations_organization.this.roots[0].id
}
