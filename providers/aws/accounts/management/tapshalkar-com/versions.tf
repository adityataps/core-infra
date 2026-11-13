terraform {
  required_version = ">= 1.5"
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/management"
  }
}

provider "aws" {
  region = var.aws_region
}
