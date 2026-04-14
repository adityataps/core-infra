variable "project_id" {
  type        = string
  description = "GCP project ID that will own the state bucket"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name for the GCS state bucket"
}

variable "region" {
  type        = string
  description = "GCS bucket location (e.g. US, EU, us-central1)"
  default     = "US"
}

variable "state_version_retention_days" {
  type        = number
  description = "Minimum age in days before an archived (non-current) state version is eligible for deletion. Versions are only deleted when both this age threshold AND num_newer_versions >= 5 conditions are met."
  default     = 90
}
