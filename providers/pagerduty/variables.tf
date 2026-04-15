variable "api_token" {
  type        = string
  description = "PagerDuty API token. Generate from PagerDuty → My Profile → API Access Keys → Create New API Key."
  sensitive   = true
}

variable "admin_email" {
  type        = string
  description = "Email address of the PagerDuty admin user to target in the escalation policy."
}
