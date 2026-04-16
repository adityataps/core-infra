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

resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/${data.terraform_remote_state.pagerduty.outputs.integration_key}/enqueue"

  # PagerDuty auto-confirms HTTPS SNS subscriptions — no manual confirmation needed.
  endpoint_auto_confirms = true
}
