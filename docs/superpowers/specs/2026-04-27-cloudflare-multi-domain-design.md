# Cloudflare Multi-Domain DNS Design

**Date:** 2026-04-27
**Status:** Approved

## Overview

Add Cloudflare DNS management to the core-infra monorepo, replacing Route53 as the DNS provider. All zones and account-level resources share a single Terraform state under `providers/cloudflare/`. A reusable `modules/zone/` module enforces consistent record structure across domains; a `for_each` loop in `main.tf` instantiates it for every zone defined in `zones.tf`. A scaffold script adds new zones with minimal friction.

## Directory Structure

```
providers/cloudflare/
  modules/zone/
    main.tf        # cloudflare_zone + for_each over each record type
    variables.tf   # zone_name, account_id, and per-type record lists
    outputs.tf     # zone_id, zone_name
  zones.tf         # locals { zones = { "domain.com" = { a_records = [...] } } }
  main.tf          # module "zones" { for_each = local.zones } + account-level resources
  versions.tf      # cloudflare provider ~> 5.0, GCS backend prefix = "cloudflare"
  variables.tf     # api_token, account_id
  outputs.tf       # map of zone_name → zone_id
  terraform.tfvars # gitignored — api_token + account_id values
  backend.hcl      # gitignored — GCS bucket name
```

## Module Interface (`modules/zone/`)

### Inputs

| Variable | Type | Required | Description |
|---|---|---|---|
| `zone_name` | `string` | yes | Domain name (e.g. `"mysite.com"`) |
| `account_id` | `string` | yes | Cloudflare account ID |
| `a_records` | `list(object({ name, content, proxied, ttl }))` | no | Defaults to `[]` |
| `mx_records` | `list(object({ name, content, priority, ttl }))` | no | Defaults to `[]` |
| `cname_records` | `list(object({ name, content, proxied, ttl }))` | no | Defaults to `[]` |
| `txt_records` | `list(object({ name, content, ttl }))` | no | Defaults to `[]` |
| `srv_records` | `list(object({ name, service, proto, priority, weight, port, target, ttl }))` | no | Defaults to `[]` |

Each record type is iterated inside the module with `for_each`. Keys are `"${name}:${content}"` (or `"${name}:${port}"` for SRV) to ensure uniqueness when multiple records share a name (e.g., two `@` MX records). All optional types default to `[]` so zones omit unused types without nulls or conditionals.

### Outputs

| Output | Description |
|---|---|
| `zone_id` | Cloudflare zone ID (useful for cross-state references) |
| `zone_name` | Domain name (pass-through) |

## Root Module (`providers/cloudflare/`)

### `zones.tf`

Single source of truth for all managed zones. Each key is a domain name; each value is an object with optional record type lists. Zones omit record types they don't use.

```hcl
locals {
  zones = {
    "mysite.com" = {
      a_records = [
        # NOTE: home.mysite.com is excluded — managed by favonia/cloudflare-ddns
        { name = "@", content = "1.2.3.4", proxied = true, ttl = 1 },
      ]
      mx_records = [
        { name = "@", content = "mail.mysite.com", priority = 10, ttl = 300 },
      ]
    }
    "minecraft.example.com" = {
      a_records = [
        { name = "@", content = "1.2.3.4", proxied = false, ttl = 300 },
      ]
      srv_records = [
        { name = "_minecraft", service = "_minecraft", proto = "_tcp",
          priority = 0, weight = 5, port = 25565, target = "mc.example.com", ttl = 300 },
      ]
    }
  }
}
```

### `main.tf`

```hcl
module "zones" {
  for_each    = local.zones
  source      = "./modules/zone"
  zone_name   = each.key
  account_id  = var.account_id
  a_records   = lookup(each.value, "a_records", [])
  mx_records  = lookup(each.value, "mx_records", [])
  cname_records = lookup(each.value, "cname_records", [])
  txt_records = lookup(each.value, "txt_records", [])
  srv_records = lookup(each.value, "srv_records", [])
}

# Account-level resources (budget alerts, etc.) go here
```

## Scaffold Script (`scripts/create-cloudflare-zone.sh`)

**Usage:** `./scripts/create-cloudflare-zone.sh <domain>`

The script:
1. Validates the domain argument (non-empty, basic format check)
2. Checks `zones.tf` to confirm the domain is not already present
3. Appends a minimal zone entry stub to `zones.tf`
4. Prints the Terraform import command and next steps

**Import command format** (printed by script):
```bash
terraform import 'module.zones["mysite.com"].cloudflare_zone.this' <ZONE_ID>
```

State key uses the domain name as the map key, matching the `for_each` key in `main.tf`.

## DDNS Integration

The DDNS-managed subdomain (e.g. `home.mysite.com`) is **excluded from Terraform** — it is created and updated exclusively by `favonia/cloudflare-ddns`. Since `lifecycle { ignore_changes }` cannot be conditionally applied from a variable, keeping the record out of state entirely is the safest approach. A comment in `zones.tf` marks which subdomain is DDNS-managed.

**Recommended container:** `favonia/cloudflare-ddns`

```env
CLOUDFLARE_API_TOKEN=<scoped token: Zone:DNS:Edit for the specific zone>
DOMAINS=home.mysite.com
PROXIED=false
```

Use a scoped API token (Zone → DNS → Edit, limited to the specific zone) rather than a global token.

## Migration Steps (first domain)

1. Lower Route53 TTLs to 60–300s a few hours before cutover
2. Add domain to Cloudflare via web UI (auto-imports records for review)
3. `terraform init -backend-config="bucket=tapshalkar-com-tfstate"`
4. `terraform import 'module.zones["mysite.com"].cloudflare_zone.this' <ZONE_ID>`
5. `terraform plan` — verify no unexpected diff
6. Update nameservers at Route53 Registered Domains to Cloudflare's NS values
7. Verify propagation: `dig NS mysite.com @8.8.8.8`
8. Decommission Route53 hosted zone

## State Backend

- **Backend:** GCS, `prefix = "cloudflare"`
- **Bucket:** `tapshalkar-com-tfstate` (shared with all other providers)
- Consistent with PagerDuty, Hetzner, and GitHub provider patterns in this repo

## Future Extensions

Account-level resources (Workers, R2 buckets, WAF rulesets, Zero Trust tunnels) are added directly to `providers/cloudflare/main.tf` alongside the `module "zones"` block. No structural changes needed.
