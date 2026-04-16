variable "account_id" {
  type        = string
  description = "AWS account ID of the side-project account. Get from: terraform output -raw side_project_account_id (in providers/aws/org/)"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}
