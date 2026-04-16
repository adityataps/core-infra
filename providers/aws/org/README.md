# org

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

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_organizations_account.certs_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_account.certs_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_account.personal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_account.side_project](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_organizational_unit.certs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.personal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.projects](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organization.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for the provider (org-level resources are global, but a region is required) | `string` | `"us-east-1"` | no |
| <a name="input_certs_1_account_email"></a> [certs\_1\_account\_email](#input\_certs\_1\_account\_email) | Root email of the first certs account (must match the email used when the account was created) | `string` | n/a | yes |
| <a name="input_certs_1_account_name"></a> [certs\_1\_account\_name](#input\_certs\_1\_account\_name) | Display name of the first certs account (must match existing account name exactly) | `string` | n/a | yes |
| <a name="input_certs_2_account_email"></a> [certs\_2\_account\_email](#input\_certs\_2\_account\_email) | Root email of the second certs account (must match the email used when the account was created) | `string` | n/a | yes |
| <a name="input_certs_2_account_name"></a> [certs\_2\_account\_name](#input\_certs\_2\_account\_name) | Display name of the second certs account (must match existing account name exactly) | `string` | n/a | yes |
| <a name="input_personal_account_email"></a> [personal\_account\_email](#input\_personal\_account\_email) | Root email for the new personal member account (must be a globally unique email never registered with AWS) | `string` | n/a | yes |
| <a name="input_personal_account_name"></a> [personal\_account\_name](#input\_personal\_account\_name) | Display name for the new personal member account | `string` | n/a | yes |
| <a name="input_side_project_account_email"></a> [side\_project\_account\_email](#input\_side\_project\_account\_email) | Root email of the side-project account (must match the email used when the account was created) | `string` | n/a | yes |
| <a name="input_side_project_account_name"></a> [side\_project\_account\_name](#input\_side\_project\_account\_name) | Display name of the side-project account (must match existing account name exactly) | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_certs_account_1_id"></a> [certs\_account\_1\_id](#output\_certs\_account\_1\_id) | AWS account ID of the first certs account |
| <a name="output_certs_account_2_id"></a> [certs\_account\_2\_id](#output\_certs\_account\_2\_id) | AWS account ID of the second certs account |
| <a name="output_certs_ou_id"></a> [certs\_ou\_id](#output\_certs\_ou\_id) | ID of the certs/ OU |
| <a name="output_personal_account_id"></a> [personal\_account\_id](#output\_personal\_account\_id) | AWS account ID of the new personal member account |
| <a name="output_personal_ou_id"></a> [personal\_ou\_id](#output\_personal\_ou\_id) | ID of the personal/ OU |
| <a name="output_projects_ou_id"></a> [projects\_ou\_id](#output\_projects\_ou\_id) | ID of the projects/ OU |
| <a name="output_root_id"></a> [root\_id](#output\_root\_id) | ID of the organization root |
| <a name="output_side_project_account_id"></a> [side\_project\_account\_id](#output\_side\_project\_account\_id) | AWS account ID of the side-project account |
<!-- END_TF_DOCS -->
