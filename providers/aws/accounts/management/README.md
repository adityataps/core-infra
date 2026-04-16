# management

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_budgets_budget.per_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.github_actions_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_sns_topic.budget_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.budget_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.pagerduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [terraform_remote_state.aws_org](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.pagerduty](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for management account resources (SNS topics are regional) | `string` | `"us-east-1"` | no |
| <a name="input_budget_amounts"></a> [budget\_amounts](#input\_budget\_amounts) | Monthly budget cap in USD per linked account.<br/>Keys must be: personal, certs\_1, certs\_2, side\_project.<br/>These keys correspond to the aws/org remote state outputs. | `map(number)` | <pre>{<br/>  "certs_1": 5,<br/>  "certs_2": 5,<br/>  "personal": 10,<br/>  "side_project": 10<br/>}</pre> | no |
| <a name="input_budget_thresholds"></a> [budget\_thresholds](#input\_budget\_thresholds) | Fractional spend thresholds triggering SNS alerts (e.g. [0.5, 0.9, 1.0] = 50%, 90%, 100%) | `list(number)` | <pre>[<br/>  0.5,<br/>  0.9,<br/>  1<br/>]</pre> | no |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | GitHub repository in 'owner/repo' format for OIDC trust policy. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_github_actions_role_arn"></a> [github\_actions\_role\_arn](#output\_github\_actions\_role\_arn) | ARN of the IAM role for GitHub Actions OIDC authentication (management account) |
<!-- END_TF_DOCS -->
