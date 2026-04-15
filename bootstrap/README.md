# bootstrap

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
| [google_storage_bucket.tf_state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Globally unique name for the GCS state bucket | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID that will own the state bucket | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | GCS bucket location (e.g. US, EU, us-central1) | `string` | `"US"` | no |
| <a name="input_state_version_retention_days"></a> [state\_version\_retention\_days](#input\_state\_version\_retention\_days) | Minimum age in days before an archived (non-current) state version is eligible for deletion. Versions are only deleted when both this age threshold AND num\_newer\_versions >= 5 conditions are met. | `number` | `90` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the GCS state bucket |
| <a name="output_bucket_url"></a> [bucket\_url](#output\_bucket\_url) | gs:// URL of the state bucket |
<!-- END_TF_DOCS -->
