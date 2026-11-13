# The application owns this topic and budget. Core-infra owns only the added
# PagerDuty subscriber; it must not import or replace application resources.
data "aws_sns_topic" "bedrock_budget" {
  provider = aws.account
  name     = "payinvestigator-bedrock-budget-alerts"
}

resource "aws_sns_topic_subscription" "bedrock_budget_forwarder" {
  provider  = aws.account
  topic_arn = data.aws_sns_topic.bedrock_budget.arn
  protocol  = "lambda"
  endpoint  = data.terraform_remote_state.management.outputs.budget_forwarder_lambda_arn
}
