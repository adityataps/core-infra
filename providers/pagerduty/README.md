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
| [pagerduty_service.aws_billing](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/resources/service) | resource |
| [pagerduty_service.gcp_monitoring](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/resources/service) | resource |
| [pagerduty_service_integration.aws_cloudwatch](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/resources/service_integration) | resource |
| [pagerduty_service_integration.gcp](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/resources/service_integration) | resource |
| [pagerduty_user.admin](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/data-sources/user) | data source |
| [pagerduty_vendor.cloudwatch](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/data-sources/vendor) | data source |
| [pagerduty_vendor.gcp](https://registry.terraform.io/providers/pagerduty/pagerduty/latest/docs/data-sources/vendor) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | Email address of the PagerDuty admin user to target in the escalation policy. | `string` | n/a | yes |
| <a name="input_api_token"></a> [api\_token](#input\_api\_token) | PagerDuty API token. Generate from PagerDuty → My Profile → API Access Keys → Create New API Key. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_aws_integration_key"></a> [aws\_integration\_key](#output\_aws\_integration\_key) | PagerDuty Amazon CloudWatch service integration key. Used as the SNS HTTPS endpoint via https://events.pagerduty.com/integration/<key>/enqueue — this endpoint handles SNS SubscriptionConfirmation automatically. |
| <a name="output_gcp_integration_key"></a> [gcp\_integration\_key](#output\_gcp\_integration\_key) | PagerDuty routing key for the GCP Monitoring service integration. Consumed automatically via terraform\_remote\_state in GCP project roots. |
<!-- END_TF_DOCS -->
