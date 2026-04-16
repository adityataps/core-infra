variable "aws_region" {
  type        = string
  description = "AWS region for the provider (org-level resources are global, but a region is required)"
  default     = "us-east-1"
}

variable "certs_1_account_name" {
  type        = string
  description = "Display name of the first certs account (must match existing account name exactly)"
}

variable "certs_1_account_email" {
  type        = string
  description = "Root email of the first certs account (must match the email used when the account was created)"
}

variable "certs_2_account_name" {
  type        = string
  description = "Display name of the second certs account (must match existing account name exactly)"
}

variable "certs_2_account_email" {
  type        = string
  description = "Root email of the second certs account (must match the email used when the account was created)"
}

variable "side_project_account_name" {
  type        = string
  description = "Display name of the side-project account (must match existing account name exactly)"
}

variable "side_project_account_email" {
  type        = string
  description = "Root email of the side-project account (must match the email used when the account was created)"
}

variable "personal_account_name" {
  type        = string
  description = "Display name for the new personal member account"
}

variable "personal_account_email" {
  type        = string
  description = "Root email for the new personal member account (must be a globally unique email never registered with AWS)"
}
