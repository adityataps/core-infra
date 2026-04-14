variable "project_id" {
  type        = string
  description = "The GCP project ID to configure"
}

variable "project_name" {
  type        = string
  description = "Human-readable display name for the GCP project"
}

variable "billing_account" {
  type        = string
  description = "Billing account ID to associate with the project (format: XXXXXX-XXXXXX-XXXXXX)"
}

variable "admin_user" {
  type        = string
  description = "Google account email to bind as project owner (e.g. user@gmail.com)"
}

variable "region" {
  type        = string
  description = "Default GCP region"
  default     = "us-central1"
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD"
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds that trigger email alerts (e.g. [0.5, 0.9, 1.0])"
  default     = [0.5, 0.9, 1.0]

  validation {
    condition     = alltrue([for t in var.budget_thresholds : t > 0 && t <= 1.5])
    error_message = "Budget thresholds must be between 0 and 1.5."
  }
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the GCP project"
  default = {
    "managed-by" = "terraform"
  }
}

variable "enabled_apis" {
  type        = list(string)
  description = "GCP API services to enable on the project"
  default = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
}

variable "github_repo" {
  type        = string
  description = "GitHub repository for Workload Identity Federation in 'owner/repo' format. Set to null to skip WIF setup."
  default     = null
}
