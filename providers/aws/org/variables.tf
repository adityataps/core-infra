variable "aws_region" {
  type        = string
  description = "AWS region for the provider (org-level resources are global, but a region is required)"
  default     = "us-east-1"
}
