data "aws_organizations_organization" "budget_forwarder" {}

locals {
  # SNS and Lambda must share a region for this subscription protocol. All
  # current account budgets use this region. Add a regional forwarder if needed.
  budget_forwarder_topics = toset(concat(
    [for account in data.aws_organizations_organization.budget_forwarder.accounts :
      "arn:aws:sns:${var.aws_region}:${account.id}:budget-alerts" if account.status == "ACTIVE"
    ],
    ["arn:aws:sns:${var.aws_region}:446643829639:payinvestigator-bedrock-budget-alerts"],
  ))
}

data "archive_file" "budget_forwarder" {
  type        = "zip"
  source_file = "${path.module}/../../../../../scripts/aws-budget-forwarder/handler.py"
  output_path = "${path.module}/.terraform/aws-budget-forwarder.zip"
}

resource "aws_cloudwatch_log_group" "budget_forwarder" {
  name              = "/aws/lambda/budget-pagerduty-forwarder"
  retention_in_days = 14
}

resource "aws_sqs_queue" "budget_delivery_failures" {
  name                      = "budget-pagerduty-delivery-failures"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_iam_role" "budget_forwarder" {
  name = "budget-pagerduty-forwarder"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "budget_forwarder" {
  name = "logs-and-failed-delivery"
  role = aws_iam_role.budget_forwarder.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.budget_forwarder.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.budget_delivery_failures.arn
      },
    ]
  })
}

resource "aws_lambda_function" "budget_forwarder" {
  function_name    = "budget-pagerduty-forwarder"
  description      = "Converts AWS budget SNS notifications to PagerDuty Events API v2."
  role             = aws_iam_role.budget_forwarder.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.budget_forwarder.output_path
  source_code_hash = data.archive_file.budget_forwarder.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      PAGERDUTY_ROUTING_KEY = sensitive(data.terraform_remote_state.pagerduty.outputs.aws_budget_integration_key)
    }
  }

  depends_on = [aws_iam_role_policy.budget_forwarder]
}

resource "aws_lambda_function_event_invoke_config" "budget_forwarder" {
  function_name                = aws_lambda_function.budget_forwarder.function_name
  maximum_retry_attempts       = 2
  maximum_event_age_in_seconds = 21600

  destination_config {
    on_failure {
      destination = aws_sqs_queue.budget_delivery_failures.arn
    }
  }
}

resource "aws_lambda_permission" "budget_sns" {
  for_each      = local.budget_forwarder_topics
  statement_id  = "BudgetTopic${substr(sha256(each.value), 0, 16)}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.budget_forwarder.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = each.value
}

# Budget-delivery health stays visible in CloudWatch without paging: PagerDuty
# is reserved for budget threshold notifications.
resource "aws_cloudwatch_metric_alarm" "budget_forwarder_errors" {
  alarm_name          = "budget-pagerduty-forwarder-errors"
  alarm_description   = "Budget delivery to PagerDuty failed. Inspect the forwarder logs, routing integration, and budget-pagerduty-delivery-failures queue; do not print routing keys or event payloads."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.budget_forwarder.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  actions_enabled     = false
  alarm_actions       = []
  ok_actions          = []
}

resource "aws_cloudwatch_metric_alarm" "budget_delivery_failures" {
  alarm_name          = "budget-pagerduty-undelivered-notifications"
  alarm_description   = "Budget notifications exhausted Lambda retries. Inspect and redrive the budget-pagerduty-delivery-failures queue after correcting the delivery issue. Its retention period is 14 days."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.budget_delivery_failures.name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  actions_enabled     = false
  alarm_actions       = []
  ok_actions          = []
}
