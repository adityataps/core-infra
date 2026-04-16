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

# ── AWS remote states ──────────────────────────────────────────────────────────

data "terraform_remote_state" "aws_management" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/management"
  }
}

data "terraform_remote_state" "aws_personal" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/personal"
  }
}

data "terraform_remote_state" "aws_certs_1" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/certs/account-1"
  }
}

data "terraform_remote_state" "aws_certs_2" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/certs/account-2"
  }
}

data "terraform_remote_state" "aws_side_project" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/projects/side-project"
  }
}

# ── AWS Actions secrets ────────────────────────────────────────────────────────

resource "github_actions_secret" "aws_management_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_MANAGEMENT_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_management.outputs.github_actions_role_arn
}

resource "github_actions_secret" "aws_personal_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_PERSONAL_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_personal.outputs.github_actions_role_arn
}

resource "github_actions_secret" "aws_certs_1_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_CERTS_1_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_certs_1.outputs.github_actions_role_arn
}

resource "github_actions_secret" "aws_certs_2_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_CERTS_2_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_certs_2.outputs.github_actions_role_arn
}

resource "github_actions_secret" "aws_side_project_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_SIDE_PROJECT_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_side_project.outputs.github_actions_role_arn
}

# ── AWS Actions variables ──────────────────────────────────────────────────────

resource "github_actions_variable" "aws_region" {
  repository    = data.github_repository.core_infra.name
  variable_name = "AWS_REGION"
  value         = "us-east-1"
}
