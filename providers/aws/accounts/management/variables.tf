variable "aws_region" {
  type        = string
  description = "AWS region for management account resources (SNS topics are regional)"
  default     = "us-east-1"
}

variable "budget_amounts" {
  type        = map(number)
  description = <<-EOT
    Monthly budget cap in USD per linked account.
    Keys must be: personal, certs_1, certs_2, side_project.
    These keys correspond to the aws/org remote state outputs.
  EOT
  default = {
    personal     = 10
    certs_1      = 5
    certs_2      = 5
    side_project = 10
  }
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds triggering SNS alerts (e.g. [0.5, 0.9, 1.0] = 50%, 90%, 100%)"
  default     = [0.5, 0.9, 1.0]

  validation {
    condition     = alltrue([for t in var.budget_thresholds : t > 0 && t <= 1.5])
    error_message = "Budget thresholds must be between 0 and 1.5."
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in 'owner/repo' format for OIDC trust policy."
}
