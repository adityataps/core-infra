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

  account_name              = "tapshalkar-com-sandbox"
  region                    = var.region
  github_repo               = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount             = var.budget_amount
  budget_thresholds         = var.budget_thresholds
  notification_email        = var.notification_email
  pagerduty_integration_key = data.terraform_remote_state.pagerduty.outputs.aws_integration_key
}
