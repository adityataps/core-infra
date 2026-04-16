variable "domain" {
  type        = string
  description = "Google Workspace domain used to look up the GCP organization (e.g. tapshalkar.com)."
}

variable "admin_user" {
  type        = string
  description = "Google Workspace email to bind as Organization Admin (e.g. aditya@tapshalkar.com)."

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.admin_user))
    error_message = "admin_user must be a valid email address."
  }
}
