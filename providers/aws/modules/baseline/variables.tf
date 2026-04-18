variable "account_name" {
  type        = string
  description = "Logical name of this account (used in IAM role name, e.g. 'personal', 'certs-1')"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in 'owner/repo' format. OIDC tokens are scoped to this repo only."
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD for this account"
  default     = 10
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds that trigger SNS alerts (e.g. [0.5, 0.9, 1.0] = 50%, 90%, 100%)"
  default     = [0.5, 0.9, 1.0]
}

variable "notification_email" {
  type        = string
  description = "Email address for budget alert SNS subscription"
}

variable "pagerduty_integration_key" {
  type        = string
  description = "PagerDuty Amazon CloudWatch service integration key. When set, an SNS HTTPS subscription is created to forward budget alerts to PagerDuty via the /integration/<key>/enqueue endpoint, which handles SNS SubscriptionConfirmation automatically."
  default     = ""
}
