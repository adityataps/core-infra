# personal

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_baseline"></a> [baseline](#module\_baseline) | ../../modules/baseline | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [terraform_remote_state.github](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID of the personal member account. Get from: terraform output -raw personal\_account\_id (in providers/aws/org/) | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region for this account | `string` | `"us-east-1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_github_actions_role_arn"></a> [github\_actions\_role\_arn](#output\_github\_actions\_role\_arn) | ARN of the IAM role for GitHub Actions OIDC authentication (personal account) |
<!-- END_TF_DOCS -->
