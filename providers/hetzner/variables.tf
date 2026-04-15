variable "api_token" {
  type        = string
  description = "Hetzner Cloud API token. Generate from Hetzner Cloud Console → Project → Security → API Tokens → Generate API Token."
  sensitive   = true
}
