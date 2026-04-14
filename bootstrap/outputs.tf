output "bucket_name" {
  description = "Name of the GCS state bucket"
  value       = google_storage_bucket.tf_state.name
}

output "bucket_url" {
  description = "gs:// URL of the state bucket"
  value       = google_storage_bucket.tf_state.url
}
