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
