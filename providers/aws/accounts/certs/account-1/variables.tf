variable "account_id" {
  type        = string
  description = "AWS account ID of the first certs account. Get from: terraform output -raw certs_account_1_id (in providers/aws/org/)"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}
