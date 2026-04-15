# mongodb

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_mongodbatlas"></a> [mongodbatlas](#requirement\_mongodbatlas) | ~> 2.0 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_org_id"></a> [org\_id](#input\_org\_id) | MongoDB Atlas organization ID. Found in Atlas → Organization Settings → Organization ID. | `string` | n/a | yes |
| <a name="input_private_key"></a> [private\_key](#input\_private\_key) | MongoDB Atlas API private key. | `string` | n/a | yes |
| <a name="input_public_key"></a> [public\_key](#input\_public\_key) | MongoDB Atlas API public key. Generate from Atlas → Access Manager → API Keys → Create API Key. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
