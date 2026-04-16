# github

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_github"></a> [github](#provider\_github) | 6.11.1 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [github_actions_secret.gcp_service_account](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_actions_secret.gcp_wif_provider](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_repository.core_infra](https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/repository) | data source |
| [terraform_remote_state.management](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub username or organization owning the repositories. | `string` | `"adityataps"` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub personal access token with repo and secrets write permissions. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_core_infra_repo_full_name"></a> [core\_infra\_repo\_full\_name](#output\_core\_infra\_repo\_full\_name) | Full name of the core-infra repository (owner/repo). Consumed by project roots via terraform\_remote\_state to set github\_repo. |
<!-- END_TF_DOCS -->
