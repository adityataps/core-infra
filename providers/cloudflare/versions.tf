terraform {
  required_version = ">= 1.5"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config=backend.hcl (committed, non-sensitive)
    prefix = "cloudflare"
  }
}

provider "cloudflare" {
  api_token = var.api_token
}
