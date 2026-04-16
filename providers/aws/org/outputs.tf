output "root_id" {
  description = "ID of the organization root"
  value       = data.aws_organizations_organization.this.roots[0].id
}

output "personal_ou_id" {
  description = "ID of the personal/ OU"
  value       = aws_organizations_organizational_unit.personal.id
}

output "certs_ou_id" {
  description = "ID of the certs/ OU"
  value       = aws_organizations_organizational_unit.certs.id
}

output "projects_ou_id" {
  description = "ID of the projects/ OU"
  value       = aws_organizations_organizational_unit.projects.id
}

output "personal_account_id" {
  description = "AWS account ID of the new personal member account"
  value       = aws_organizations_account.personal.id
}

output "certs_account_1_id" {
  description = "AWS account ID of the first certs account"
  value       = aws_organizations_account.certs_1.id
}

output "certs_account_2_id" {
  description = "AWS account ID of the second certs account"
  value       = aws_organizations_account.certs_2.id
}

output "side_project_account_id" {
  description = "AWS account ID of the side-project account"
  value       = aws_organizations_account.side_project.id
}
