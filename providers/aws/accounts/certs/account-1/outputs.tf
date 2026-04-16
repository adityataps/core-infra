output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (certs account 1)"
  value       = module.baseline.github_actions_role_arn
}
