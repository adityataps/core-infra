output "root_id" {
  description = "ID of the organization root"
  value       = aws_organizations_organization.this.roots[0].id
}

output "personal_ou_id" {
  description = "ID of the personal/ OU"
  value       = aws_organizations_organizational_unit.ous["personal"].id
}

output "certs_ou_id" {
  description = "ID of the certs/ OU"
  value       = aws_organizations_organizational_unit.ous["certs"].id
}

output "projects_ou_id" {
  description = "ID of the projects/ OU"
  value       = aws_organizations_organizational_unit.ous["projects"].id
}

output "management_ou_id" {
  description = "ID of the management/ OU"
  value       = aws_organizations_organizational_unit.ous["management"].id
}

output "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "ID of the IAM Identity Center identity store"
  value       = local.identity_store_id
}

output "admin_user_id" {
  description = "Identity Center user ID for aditya@tapshalkar.com"
  value       = aws_identitystore_user.aditya.user_id
}
