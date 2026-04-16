output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication (personal account)"
  value       = module.baseline.github_actions_role_arn
}
