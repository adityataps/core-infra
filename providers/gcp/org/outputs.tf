output "billing_account_id" {
  description = "Billing account ID (format: XXXXXX-XXXXXX-XXXXXX) for use in project roots."
  value       = data.google_billing_account.this.id
}

output "org_id" {
  description = "GCP organization ID"
  value       = data.google_organization.this.org_id
}

output "management_folder_resource_name" {
  description = "Resource name of the management/ folder (format: folders/<ID>). Use as folder_id in google_project."
  value       = google_folder.management.name
}

output "personal_folder_resource_name" {
  description = "Resource name of the personal/ folder (format: folders/<ID>). Use as folder_id in google_project."
  value       = google_folder.personal.name
}

output "certs_folder_resource_name" {
  description = "Resource name of the certs/ folder (format: folders/<ID>). Use as folder_id in google_project."
  value       = google_folder.certs.name
}
