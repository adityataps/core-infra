output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (tapshalkar-com-sandbox account)"
  value       = module.baseline.github_actions_role_arn
}

output "account_id" {
  description = "AWS account ID of the tapshalkar-com-sandbox account"
  value       = module.baseline.account_id
}
