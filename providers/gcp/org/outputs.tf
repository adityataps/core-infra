output "org_id" {
  description = "GCP organization ID"
  value       = data.google_organization.this.org_id
}

output "personal_folder_resource_name" {
  description = "Resource name of the personal/ folder (format: folders/<ID>). Use as folder_id in google_project."
  value       = google_folder.personal.name
}

output "certs_folder_resource_name" {
  description = "Resource name of the certs/ folder (format: folders/<ID>). Use as folder_id in google_project."
  value       = google_folder.certs.name
}
