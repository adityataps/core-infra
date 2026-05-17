variable "api_token" {
  description = "Cloudflare API token (Zone:DNS:Edit scoped)"
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}
