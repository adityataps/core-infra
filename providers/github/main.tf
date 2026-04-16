terraform {
  required_version = ">= 1.5"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

data "terraform_remote_state" "management" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "gcp/projects/management/tapshalkar-com"
  }
}

# ── Repositories ──────────────────────────────────────────────────────────────

data "github_repository" "core_infra" {
  full_name = "adityataps/core-infra"
}

# ── Actions secrets ───────────────────────────────────────────────────────────

resource "github_actions_secret" "gcp_wif_provider" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "GCP_WORKLOAD_IDENTITY_PROVIDER"
  plaintext_value = data.terraform_remote_state.management.outputs.workload_identity_provider
}

resource "github_actions_secret" "gcp_service_account" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "GCP_SERVICE_ACCOUNT"
  plaintext_value = data.terraform_remote_state.management.outputs.github_actions_service_account_email
}
