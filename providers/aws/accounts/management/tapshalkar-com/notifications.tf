resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn = module.baseline.budget_alerts_sns_topic_arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/${data.terraform_remote_state.pagerduty.outputs.integration_key}/enqueue"

  # PagerDuty auto-confirms HTTPS SNS subscriptions — no manual confirmation needed.
  endpoint_auto_confirms = true
}
