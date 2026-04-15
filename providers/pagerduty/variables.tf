variable "api_token" {
  type        = string
  description = "PagerDuty API token. Generate from PagerDuty → My Profile → API Access Keys → Create New API Key."
  sensitive   = true
}

variable "escalation_policy_id" {
  type        = string
  description = "ID of the existing PagerDuty escalation policy to import. Find it in the PagerDuty URL when viewing the policy: /escalation_policies/<ID>"
}

variable "admin_email" {
  type        = string
  description = "Email address of the PagerDuty admin user to target in the escalation policy."
}
