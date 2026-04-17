output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_actions.arn
}

output "account_id" {
  description = "AWS account ID this baseline is applied to"
  value       = data.aws_caller_identity.current.account_id
}

output "budget_alerts_sns_topic_arn" {
  description = "ARN of the SNS topic used for budget alerts"
  value       = aws_sns_topic.budget_alerts.arn
}
