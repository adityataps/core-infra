# zone

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.19.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_dns_record.a](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.cname](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.mx](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.srv](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.txt](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zone) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_a_records"></a> [a\_records](#input\_a\_records) | List of A records | <pre>list(object({<br/>    name    = string<br/>    content = string<br/>    proxied = bool<br/>    ttl     = number<br/>  }))</pre> | `[]` | no |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID | `string` | n/a | yes |
| <a name="input_cname_records"></a> [cname\_records](#input\_cname\_records) | List of CNAME records | <pre>list(object({<br/>    name    = string<br/>    content = string<br/>    proxied = bool<br/>    ttl     = number<br/>  }))</pre> | `[]` | no |
| <a name="input_mx_records"></a> [mx\_records](#input\_mx\_records) | List of MX records | <pre>list(object({<br/>    name     = string<br/>    content  = string<br/>    priority = number<br/>    ttl      = number<br/>  }))</pre> | `[]` | no |
| <a name="input_srv_records"></a> [srv\_records](#input\_srv\_records) | List of SRV records | <pre>list(object({<br/>    service  = string<br/>    proto    = string<br/>    priority = number<br/>    weight   = number<br/>    port     = number<br/>    target   = string<br/>    ttl      = number<br/>  }))</pre> | `[]` | no |
| <a name="input_txt_records"></a> [txt\_records](#input\_txt\_records) | List of TXT records | <pre>list(object({<br/>    name    = string<br/>    content = string<br/>    ttl     = number<br/>  }))</pre> | `[]` | no |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Domain name for the zone (e.g. example.com) | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | Cloudflare zone ID |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | Domain name |
<!-- END_TF_DOCS -->
