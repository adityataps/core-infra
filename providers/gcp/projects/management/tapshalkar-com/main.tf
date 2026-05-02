terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.30"
    }
  }
}

provider "google" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}

data "terraform_remote_state" "pagerduty" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "pagerduty"
  }
}

data "terraform_remote_state" "gcp_org" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "gcp/org"
  }
}

data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "github"
  }
}

module "baseline" {
  source = "../../../modules/baseline"

  project_id                    = var.project_id
  project_name                  = var.project_name
  billing_account               = var.billing_account
  admin_user                    = var.admin_user
  region                        = var.region
  budget_amount                 = var.budget_amount
  budget_thresholds             = var.budget_thresholds
  labels                        = var.labels
  enabled_apis                  = var.enabled_apis
  github_repo                   = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  enable_data_access_audit_logs = var.enable_data_access_audit_logs
  pagerduty_integration_key     = data.terraform_remote_state.pagerduty.outputs.gcp_integration_key
  folder_id                     = data.terraform_remote_state.gcp_org.outputs.management_folder_resource_name
}
