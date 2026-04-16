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

  validation {
    condition     = can(regex("^[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}$", var.billing_account))
    error_message = "billing_account must be in the format XXXXXX-XXXXXX-XXXXXX (hex characters)."
  }
}

variable "admin_user" {
  type        = string
  description = "Google account email to bind as project owner (e.g. user@gmail.com)"

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
  description = "Monthly budget cap in whole USD dollars (fractional amounts not supported by the GCP Billing Budgets API)"

  validation {
    condition     = var.budget_amount == floor(var.budget_amount) && var.budget_amount > 0
    error_message = "budget_amount must be a positive whole number (e.g. 20, not 19.99)."
  }
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds that trigger email alerts. Values between 0 (exclusive) and 1.5; values above 1.0 represent over-budget thresholds (e.g. 1.2 = 120%). Maximum 5 thresholds."
  default     = [0.5, 0.9, 1.0]

  validation {
    condition     = length(var.budget_thresholds) >= 1 && length(var.budget_thresholds) <= 5 && alltrue([for t in var.budget_thresholds : t > 0 && t <= 1.5])
    error_message = "Each budget threshold must be greater than 0 and at most 1.5, and the list must contain between 1 and 5 thresholds (GCP API limit)."
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
    "billingbudgets.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
}

variable "github_repo" {
  type        = string
  description = "GitHub repository for Workload Identity Federation in 'owner/repo' format (e.g. 'my-org/my-repo'). Set to null to skip WIF setup."
  default     = null

  validation {
    condition     = var.github_repo == null || can(regex("^[^/]+/[^/]+$", var.github_repo))
    error_message = "github_repo must be in 'owner/repo' format (e.g. 'my-org/my-repo')."
  }
}

variable "enable_data_access_audit_logs" {
  type        = bool
  description = "Enable DATA_READ and DATA_WRITE audit logs for all services. Note: these are billable beyond the 50 GiB/month free tier. ADMIN_READ logs are always enabled (free)."
  default     = true
}

variable "pagerduty_integration_key" {
  type        = string
  description = "PagerDuty integration key for GCP monitoring alerts. Null disables PagerDuty routing."
  default     = null
  sensitive   = true
}

variable "folder_id" {
  type        = string
  description = "GCP folder to place this project under (e.g. folders/1234567890). Null places the project directly under the organization."
  default     = null

  validation {
    condition     = var.folder_id == null || can(regex("^folders/[0-9]+$", var.folder_id))
    error_message = "folder_id must be in the format 'folders/<numeric-id>' (e.g. folders/1234567890)."
  }
}
