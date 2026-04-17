output "root_id" {
  description = "ID of the organization root"
  value       = aws_organizations_organization.this.roots[0].id
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

output "management_ou_id" {
  description = "ID of the management/ OU"
  value       = aws_organizations_organizational_unit.management.id
}
