locals {
  # Map of logical account name → account ID, sourced from aws/org remote state.
  # Keys must match the keys in var.budget_amounts.
  budgeted_accounts = {
    personal     = data.terraform_remote_state.aws_org.outputs.personal_account_id
    certs_1      = data.terraform_remote_state.aws_org.outputs.certs_account_1_id
    certs_2      = data.terraform_remote_state.aws_org.outputs.certs_account_2_id
    side_project = data.terraform_remote_state.aws_org.outputs.side_project_account_id
  }
}

resource "aws_budgets_budget" "per_account" {
  for_each = local.budgeted_accounts

  name              = "${each.key}-monthly"
  budget_type       = "COST"
  limit_amount      = tostring(var.budget_amounts[each.key])
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  cost_filter {
    name   = "LinkedAccount"
    values = [each.value]
  }

  dynamic "notification" {
    for_each = var.budget_thresholds
    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value * 100
      threshold_type            = "PERCENTAGE"
      notification_type         = "ACTUAL"
      subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
    }
  }
}
