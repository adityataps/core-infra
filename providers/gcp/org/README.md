# org

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 5.45.2 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_folder.certs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder) | resource |
| [google_folder.management](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder) | resource |
| [google_folder.personal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder) | resource |
| [google_organization_iam_member.admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/organization_iam_member) | resource |
| [google_organization.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_user"></a> [admin\_user](#input\_admin\_user) | Google Workspace email to bind as Organization Admin (e.g. aditya@tapshalkar.com). | `string` | n/a | yes |
| <a name="input_domain"></a> [domain](#input\_domain) | Google Workspace domain used to look up the GCP organization (e.g. tapshalkar.com). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_certs_folder_resource_name"></a> [certs\_folder\_resource\_name](#output\_certs\_folder\_resource\_name) | Resource name of the certs/ folder (format: folders/<ID>). Use as folder\_id in google\_project. |
| <a name="output_management_folder_resource_name"></a> [management\_folder\_resource\_name](#output\_management\_folder\_resource\_name) | Resource name of the management/ folder (format: folders/<ID>). Use as folder\_id in google\_project. |
| <a name="output_org_id"></a> [org\_id](#output\_org\_id) | GCP organization ID |
| <a name="output_personal_folder_resource_name"></a> [personal\_folder\_resource\_name](#output\_personal\_folder\_resource\_name) | Resource name of the personal/ folder (format: folders/<ID>). Use as folder\_id in google\_project. |
<!-- END_TF_DOCS -->
