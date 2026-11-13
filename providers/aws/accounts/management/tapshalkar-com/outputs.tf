output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (management account)"
  value       = module.baseline.github_actions_role_arn
}

output "account_id" {
  description = "AWS account ID of the management account"
  value       = module.baseline.account_id
}

output "notification_email" {
  description = "Email address used for budget alert SNS subscriptions — shared as the default across all accounts"
  value       = var.notification_email
}

output "budget_forwarder_lambda_arn" {
  description = "Central AWS budget forwarder for member-account SNS subscriptions."
  value       = aws_lambda_function.budget_forwarder.arn
  depends_on  = [aws_lambda_permission.budget_sns]
}
