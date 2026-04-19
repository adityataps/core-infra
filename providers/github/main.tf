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
    prefix = "aws/accounts/personal/tapshalkar-com-personal"
  }
}

data "terraform_remote_state" "aws_sandbox" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/personal/tapshalkar-com-sandbox"
  }
}

data "terraform_remote_state" "aws_certs" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/certs/tapshalkar-com-certs"
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

resource "github_actions_secret" "aws_sandbox_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_SANDBOX_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_sandbox.outputs.github_actions_role_arn
}

resource "github_actions_secret" "aws_certs_role_arn" {
  repository      = data.github_repository.core_infra.name
  secret_name     = "AWS_CERTS_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_certs.outputs.github_actions_role_arn
}

# ── AWS Actions variables ──────────────────────────────────────────────────────

resource "github_actions_variable" "aws_region" {
  repository    = data.github_repository.core_infra.name
  variable_name = "AWS_REGION"
  value         = "us-east-1"
}
