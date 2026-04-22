terraform {
  required_version = ">= 1.5"
  required_providers {
    pagerduty = {
      source  = "pagerduty/pagerduty"
      version = "~> 3.0"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "pagerduty"
  }
}

provider "pagerduty" {
  token = var.api_token
}
