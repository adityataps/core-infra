variable "api_token" {
  type        = string
  description = "PagerDuty API token. Generate from PagerDuty → My Profile → API Access Keys → Create New API Key."
  sensitive   = true
}

variable "admin_email" {
  type        = string
  description = "Email address of the PagerDuty admin user to target in the escalation policy."
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID to include in the PagerDuty service name, e.g. 'adits-gcp'."
}
