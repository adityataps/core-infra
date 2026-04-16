output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (management account)"
  value       = aws_iam_role.github_actions.arn
}
