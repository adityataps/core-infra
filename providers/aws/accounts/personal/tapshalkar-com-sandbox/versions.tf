terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.43"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/personal/tapshalkar-com-sandbox"
  }
}

provider "aws" {
  region = var.region
  # Uses management account credentials to create the org member account
}

provider "aws" {
  alias  = "account"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.this.id}:role/OrganizationAccountAccessRole"
  }
}
