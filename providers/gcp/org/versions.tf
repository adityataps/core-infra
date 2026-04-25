terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.29"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "gcp/org"
  }
}

provider "google" {}
