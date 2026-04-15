terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}

module "baseline" {
  source = "../../modules/baseline"

  project_id                    = var.project_id
  project_name                  = var.project_name
  billing_account               = var.billing_account
  admin_user                    = var.admin_user
  region                        = var.region
  budget_amount                 = var.budget_amount
  budget_thresholds             = var.budget_thresholds
  labels                        = var.labels
  enabled_apis                  = var.enabled_apis
  github_repo                   = var.github_repo
  enable_data_access_audit_logs = var.enable_data_access_audit_logs
}
