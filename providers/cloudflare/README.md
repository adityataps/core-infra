# cloudflare

Manages Cloudflare DNS zones for all domains. `zones.tf` is the single source of truth — add one entry per domain. The `modules/zone/` module owns the `cloudflare_zone` resource and all DNS record types.

## Setup

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in api_token + account_id
terraform init -backend-config=backend.hcl
```

API token scopes: **Zone:Zone:Edit** + **Zone:DNS:Edit**.

## Adding a new zone

```bash
# From repo root:
./scripts/create-cloudflare-zone.sh example.com
# Fill in DNS records in providers/cloudflare/zones.tf, then:
cd providers/cloudflare
terraform import 'module.zones["example.com"].cloudflare_zone.this' <ZONE_ID>
# Import each existing record, then:
terraform plan   # expect no changes
terraform apply
```

## DDNS-managed records

Records updated by an external DDNS agent must be excluded from `zones.tf` and never imported. Add a comment documenting the exclusion. Terraform will not touch unmanaged records.

## TXT record content

Specify content **without** surrounding double quotes — the provider adds them. Example: `content = "v=spf1 include:_spf.google.com ~all"`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_zones"></a> [zones](#module\_zones) | ./modules/zone | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID | `string` | n/a | yes |
| <a name="input_api_token"></a> [api\_token](#input\_api\_token) | Cloudflare API token (Zone:DNS:Edit scoped) | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_zone_ids"></a> [zone\_ids](#output\_zone\_ids) | Map of zone name to Cloudflare zone ID |
<!-- END_TF_DOCS -->
