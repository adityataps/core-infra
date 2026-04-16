variable "github_owner" {
  type        = string
  description = "GitHub username or organization owning the repositories."
  default     = "adityataps"
}

variable "github_token" {
  type        = string
  description = "GitHub personal access token with repo and secrets write permissions."
  sensitive   = true
}
