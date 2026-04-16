# my-project

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 5.0 |

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
| [terraform_remote_state.gcp_org](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.github](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.pagerduty](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_user"></a> [admin\_user](#input\_admin\_user) | Google account email to bind as project owner | `string` | n/a | yes |
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | Billing account ID to associate with all projects in this org (format: XXXXXX-XXXXXX-XXXXXX) | `string` | n/a | yes |
| <a name="input_budget_amount"></a> [budget\_amount](#input\_budget\_amount) | Monthly budget cap in USD | `number` | n/a | yes |
| <a name="input_budget_thresholds"></a> [budget\_thresholds](#input\_budget\_thresholds) | Fractional spend thresholds for budget alerts | `list(number)` | <pre>[<br/>  0.5,<br/>  0.9,<br/>  1<br/>]</pre> | no |
| <a name="input_enable_data_access_audit_logs"></a> [enable\_data\_access\_audit\_logs](#input\_enable\_data\_access\_audit\_logs) | Enable DATA\_READ and DATA\_WRITE audit logs. Billable beyond 50 GiB/month free tier. | `bool` | `true` | no |
| <a name="input_enabled_apis"></a> [enabled\_apis](#input\_enabled\_apis) | GCP APIs to enable | `list(string)` | <pre>[<br/>  "compute.googleapis.com",<br/>  "iam.googleapis.com",<br/>  "cloudbilling.googleapis.com",<br/>  "billingbudgets.googleapis.com",<br/>  "cloudresourcemanager.googleapis.com",<br/>  "logging.googleapis.com",<br/>  "monitoring.googleapis.com",<br/>  "iamcredentials.googleapis.com"<br/>]</pre> | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the project | `map(string)` | <pre>{<br/>  "env": "personal",<br/>  "managed-by": "terraform"<br/>}</pre> | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Human-readable display name for the GCP project | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Default GCP region | `string` | `"us-central1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_billing_account_id"></a> [billing\_account\_id](#output\_billing\_account\_id) | Billing account ID used by this org. Consumed by other project roots via terraform\_remote\_state. |
| <a name="output_github_actions_service_account_email"></a> [github\_actions\_service\_account\_email](#output\_github\_actions\_service\_account\_email) | Email of the GitHub Actions service account (set as GCP\_SERVICE\_ACCOUNT GitHub secret) |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The GCP project ID |
| <a name="output_project_number"></a> [project\_number](#output\_project\_number) | The GCP project number |
| <a name="output_workload_identity_provider"></a> [workload\_identity\_provider](#output\_workload\_identity\_provider) | WIF provider resource name (set as GCP\_WORKLOAD\_IDENTITY\_PROVIDER GitHub secret) |
<!-- END_TF_DOCS -->
