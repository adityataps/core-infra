data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "budget_alerts" {
  name = "budget-alerts"
}

resource "aws_sns_topic_policy" "budget_alerts" {
  arn = aws_sns_topic.budget_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.budget_alerts.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_subscription" "pagerduty" {
  count     = var.pagerduty_integration_key != "" ? 1 : 0
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/${var.pagerduty_integration_key}/enqueue"

  # PagerDuty's service integration endpoint (/integration/<key>/enqueue) handles SNS
  # SubscriptionConfirmation automatically — no manual confirmation step required.
  endpoint_auto_confirms = true
}

resource "aws_budgets_budget" "this" {
  name              = "${var.account_name}-monthly"
  budget_type       = "COST"
  limit_amount      = tostring(var.budget_amount)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

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
