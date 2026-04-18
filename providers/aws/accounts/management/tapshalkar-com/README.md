# `management/tapshalkar-com`

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
| <a name="module_baseline"></a> [baseline](#module\_baseline) | ../../../modules/baseline | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [terraform_remote_state.github](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.pagerduty](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for management account resources (SNS topics are regional) | `string` | `"us-east-1"` | no |
| <a name="input_budget_amount"></a> [budget\_amount](#input\_budget\_amount) | Monthly budget cap in USD for the management account | `number` | `10` | no |
| <a name="input_budget_thresholds"></a> [budget\_thresholds](#input\_budget\_thresholds) | Fractional spend thresholds triggering SNS alerts (e.g. [0.5, 0.9, 1.0] = 50%, 90%, 100%) | `list(number)` | <pre>[<br/>  0.5,<br/>  0.9,<br/>  1<br/>]</pre> | no |
| <a name="input_notification_email"></a> [notification\_email](#input\_notification\_email) | Email address for budget alert SNS subscription | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | AWS account ID of the management account |
| <a name="output_github_actions_role_arn"></a> [github\_actions\_role\_arn](#output\_github\_actions\_role\_arn) | ARN of the IAM role for GitHub Actions OIDC authentication (management account) |
<!-- END_TF_DOCS -->
