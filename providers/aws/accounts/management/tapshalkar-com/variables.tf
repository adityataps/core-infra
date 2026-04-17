variable "aws_region" {
  type        = string
  description = "AWS region for management account resources (SNS topics are regional)"
  default     = "us-east-1"
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD for the management account"
  default     = 10
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds triggering SNS alerts (e.g. [0.5, 0.9, 1.0] = 50%, 90%, 100%)"
  default     = [0.5, 0.9, 1.0]
}

variable "notification_email" {
  type        = string
  description = "Email address for budget alert SNS subscription"
}
