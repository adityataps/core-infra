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

  account_name                = "tapshalkar-com"
  region                      = var.aws_region
  github_repo                 = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount               = var.budget_amount
  budget_thresholds           = var.budget_thresholds
  notification_email          = var.notification_email
  budget_forwarder_lambda_arn = aws_lambda_function.budget_forwarder.arn
  enable_budget_forwarder     = true

  depends_on = [aws_lambda_permission.budget_sns]
}
