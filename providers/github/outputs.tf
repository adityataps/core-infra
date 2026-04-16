output "core_infra_repo_full_name" {
  description = "Full name of the core-infra repository (owner/repo). Consumed by project roots via terraform_remote_state to set github_repo."
  value       = data.github_repository.core_infra.full_name
}
