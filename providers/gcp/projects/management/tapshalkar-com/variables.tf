variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "project_name" {
  type        = string
  description = "Human-readable display name for the GCP project"
}

variable "billing_account" {
  type        = string
  description = "Billing account ID to associate with all projects in this org (format: XXXXXX-XXXXXX-XXXXXX)"

  validation {
    condition     = can(regex("^[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}$", var.billing_account))
    error_message = "billing_account must be in the format XXXXXX-XXXXXX-XXXXXX (hex characters)."
  }
}

variable "admin_user" {
  type        = string
  description = "Google account email to bind as project owner"

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.admin_user))
    error_message = "admin_user must be a valid email address."
  }
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
  description = "Fractional spend thresholds for budget alerts"
  default     = [0.5, 0.9, 1.0]
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the project"
  default = {
    env          = "personal"
    "managed-by" = "terraform"
  }
}

variable "enabled_apis" {
  type        = list(string)
  description = "GCP APIs to enable"
  default = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
}

variable "enable_data_access_audit_logs" {
  type        = bool
  description = "Enable DATA_READ and DATA_WRITE audit logs. Billable beyond 50 GiB/month free tier."
  default     = true
}

