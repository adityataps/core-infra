output "core_infra_repo_full_name" {
  description = "Full name of the core-infra repository (owner/repo). Consumed by project roots via terraform_remote_state to set github_repo."
  value       = data.github_repository.core_infra.full_name
}

output "aws_region" {
  description = "Default AWS region used across all AWS accounts"
  value       = github_actions_variable.aws_region.value
}
