terraform {
  required_version = ">= 1.5"
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.0"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "mongodb"
  }
}

provider "mongodbatlas" {
  public_key  = var.public_key
  private_key = var.private_key
}
