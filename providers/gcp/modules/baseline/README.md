# baseline

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
| [google_billing_budget.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget) | resource |
| [google_iam_workload_identity_pool.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_monitoring_notification_channel.budget_email](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel) | resource |
| [google_monitoring_notification_channel.pagerduty](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_iam_audit_config.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_audit_config) | resource |
| [google_project_iam_member.admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.github_actions_roles](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.github_actions](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.github_wif](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_user"></a> [admin\_user](#input\_admin\_user) | Google account email to bind as project owner (e.g. user@gmail.com) | `string` | n/a | yes |
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | Billing account ID to associate with the project (format: XXXXXX-XXXXXX-XXXXXX) | `string` | n/a | yes |
| <a name="input_budget_amount"></a> [budget\_amount](#input\_budget\_amount) | Monthly budget cap in whole USD dollars (fractional amounts not supported by the GCP Billing Budgets API) | `number` | n/a | yes |
| <a name="input_budget_thresholds"></a> [budget\_thresholds](#input\_budget\_thresholds) | Fractional spend thresholds that trigger email alerts. Values between 0 (exclusive) and 1.5; values above 1.0 represent over-budget thresholds (e.g. 1.2 = 120%). Maximum 5 thresholds. | `list(number)` | <pre>[<br/>  0.5,<br/>  0.9,<br/>  1<br/>]</pre> | no |
| <a name="input_enable_data_access_audit_logs"></a> [enable\_data\_access\_audit\_logs](#input\_enable\_data\_access\_audit\_logs) | Enable DATA\_READ and DATA\_WRITE audit logs for all services. Note: these are billable beyond the 50 GiB/month free tier. ADMIN\_READ logs are always enabled (free). | `bool` | `true` | no |
| <a name="input_enabled_apis"></a> [enabled\_apis](#input\_enabled\_apis) | GCP API services to enable on the project | `list(string)` | <pre>[<br/>  "compute.googleapis.com",<br/>  "iam.googleapis.com",<br/>  "cloudbilling.googleapis.com",<br/>  "billingbudgets.googleapis.com",<br/>  "cloudresourcemanager.googleapis.com",<br/>  "logging.googleapis.com",<br/>  "monitoring.googleapis.com",<br/>  "iamcredentials.googleapis.com"<br/>]</pre> | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | GCP folder to place this project under (e.g. folders/1234567890). Null places the project directly under the organization. | `string` | `null` | no |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | GitHub repository for Workload Identity Federation in 'owner/repo' format (e.g. 'my-org/my-repo'). Set to null to skip WIF setup. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the GCP project | `map(string)` | <pre>{<br/>  "managed-by": "terraform"<br/>}</pre> | no |
| <a name="input_pagerduty_integration_key"></a> [pagerduty\_integration\_key](#input\_pagerduty\_integration\_key) | PagerDuty integration key for GCP monitoring alerts. Null disables PagerDuty routing. | `string` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID to configure | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Human-readable display name for the GCP project | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Default GCP region | `string` | `"us-central1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_github_actions_service_account_email"></a> [github\_actions\_service\_account\_email](#output\_github\_actions\_service\_account\_email) | Email of the GitHub Actions service account (null if github\_repo not set) |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The GCP project ID |
| <a name="output_project_number"></a> [project\_number](#output\_project\_number) | The GCP project number |
| <a name="output_workload_identity_provider"></a> [workload\_identity\_provider](#output\_workload\_identity\_provider) | Full WIF provider resource name for use in GitHub Actions (null if github\_repo not set) |
<!-- END_TF_DOCS -->
