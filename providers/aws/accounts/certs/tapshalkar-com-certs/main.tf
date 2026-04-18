data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/org"
  }
}

resource "aws_organizations_account" "this" {
  name      = "tapshalkar-com-certs"
  email     = var.account_email
  parent_id = data.terraform_remote_state.org.outputs.certs_ou_id

  lifecycle {
    prevent_destroy = true
  }
}

data "terraform_remote_state" "management" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "aws/accounts/management"
  }
}

data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "github"
  }
}

data "terraform_remote_state" "pagerduty" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "pagerduty"
  }
}

module "baseline" {
  source = "../../../modules/baseline"

  providers = {
    aws = aws.account
  }

  account_name              = "tapshalkar-com-certs"
  region                    = var.region
  github_repo               = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount             = var.budget_amount
  budget_thresholds         = var.budget_thresholds
  notification_email        = coalesce(var.notification_email, data.terraform_remote_state.management.outputs.notification_email)
  pagerduty_integration_key = data.terraform_remote_state.pagerduty.outputs.aws_integration_key
}
