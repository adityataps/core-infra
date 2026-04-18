variable "account_email" {
  type        = string
  description = "Root email address for the tapshalkar-com-personal AWS account"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD for this account"
  default     = 10
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds triggering SNS alerts (e.g. [0.5, 0.9, 1.0])"
  default     = [0.5, 0.9, 1.0]
}

variable "notification_email" {
  type        = string
  description = "Email address for budget alert SNS subscription. Defaults to the management account's notification_email if not set."
  default     = null
}
