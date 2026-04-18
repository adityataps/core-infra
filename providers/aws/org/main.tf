resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  aws_service_access_principals = [
    "sso.amazonaws.com",
  ]
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
