# pagerduty

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_pagerduty"></a> [pagerduty](#requirement\_pagerduty) | ~> 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_pagerduty"></a> [pagerduty](#provider\_pagerduty) | 3.32.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [pagerduty_escalation_policy.default](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/resources/escalation_policy) | resource |
| [pagerduty_service.gcp_monitoring](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/resources/service) | resource |
| [pagerduty_service_integration.gcp](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/resources/service_integration) | resource |
| [pagerduty_user.admin](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/data-sources/user) | data source |
| [pagerduty_vendor.gcp](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/data-sources/vendor) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | Email address of the PagerDuty admin user to target in the escalation policy. | `string` | n/a | yes |
| <a name="input_api_token"></a> [api\_token](#input\_api\_token) | PagerDuty API token. Generate from PagerDuty → My Profile → API Access Keys → Create New API Key. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_integration_key"></a> [integration\_key](#output\_integration\_key) | PagerDuty routing key for the GCP Monitoring service integration. Paste into providers/gcp/projects/adits-gcp/terraform.tfvars as pagerduty\_integration\_key. |
<!-- END_TF_DOCS -->
