output "org_id" {
  description = "GCP organization ID"
  value       = data.google_organization.this.org_id
}

output "personal_folder_id" {
  description = "Resource name of the personal/ folder (format: folders/<ID>)"
  value       = google_folder.personal.name
}

output "certs_folder_id" {
  description = "Resource name of the certs/ folder (format: folders/<ID>)"
  value       = google_folder.certs.name
}
