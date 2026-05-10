# Cloudflare Multi-Domain DNS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `providers/cloudflare/` with a reusable zone module, a `for_each`-driven root, and a scaffold script — then import the first domain into state.

**Architecture:** A single Terraform root under `providers/cloudflare/` holds all zones in a `local.zones` map (`zones.tf`). `main.tf` iterates over that map with `module "zones" { for_each = local.zones }`, delegating per-zone resources to `modules/zone/`. Common account-level resources live in `main.tf` alongside the module call.

**Tech Stack:** Terraform ≥ 1.5, cloudflare/cloudflare provider ~> 5.0, GCS remote state backend, Bash scaffold script.

---

## File Map

| File | Role |
|---|---|
| `providers/cloudflare/versions.tf` | Provider + GCS backend declaration |
| `providers/cloudflare/variables.tf` | `api_token`, `account_id` inputs |
| `providers/cloudflare/outputs.tf` | `zone_ids` map output |
| `providers/cloudflare/zones.tf` | `local.zones` map — single source of truth for all domains |
| `providers/cloudflare/main.tf` | `module "zones"` for_each + account-level resources |
| `providers/cloudflare/modules/zone/variables.tf` | Module inputs: zone_name, account_id, record lists |
| `providers/cloudflare/modules/zone/main.tf` | `cloudflare_zone` + `cloudflare_dns_record` resources |
| `providers/cloudflare/modules/zone/outputs.tf` | `zone_id`, `zone_name` outputs |
| `scripts/create-cloudflare-zone.sh` | Appends a zone stub to `zones.tf`, prints import command |

---

### Task 1: Provider root scaffolding

**Files:**
- Create: `providers/cloudflare/versions.tf`
- Create: `providers/cloudflare/variables.tf`
- Create: `providers/cloudflare/outputs.tf`

- [ ] **Step 1: Create `versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "cloudflare"
  }
}

provider "cloudflare" {
  api_token = var.api_token
}
```

- [ ] **Step 2: Create `variables.tf`**

```hcl
variable "api_token" {
  description = "Cloudflare API token (Zone:DNS:Edit scoped)"
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}
```

- [ ] **Step 3: Create `outputs.tf`**

```hcl
output "zone_ids" {
  description = "Map of zone name to Cloudflare zone ID"
  value       = { for k, v in module.zones : k => v.zone_id }
}
```

- [ ] **Step 4: Validate formatting**

```bash
cd providers/cloudflare
terraform fmt -recursive
```

Expected: no output (files already formatted, or files reformatted silently).

- [ ] **Step 5: Commit**

```bash
git add providers/cloudflare/versions.tf providers/cloudflare/variables.tf providers/cloudflare/outputs.tf
git commit -m "feat(cloudflare): scaffold provider root — versions, variables, outputs"
```

---

### Task 2: Zone module — variables and outputs

**Files:**
- Create: `providers/cloudflare/modules/zone/variables.tf`
- Create: `providers/cloudflare/modules/zone/outputs.tf`

- [ ] **Step 1: Create `modules/zone/variables.tf`**

```hcl
variable "zone_name" {
  description = "Domain name for the zone (e.g. example.com)"
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "a_records" {
  description = "List of A records"
  type = list(object({
    name    = string
    content = string
    proxied = bool
    ttl     = number
  }))
  default = []
}

variable "mx_records" {
  description = "List of MX records"
  type = list(object({
    name     = string
    content  = string
    priority = number
    ttl      = number
  }))
  default = []
}

variable "cname_records" {
  description = "List of CNAME records"
  type = list(object({
    name    = string
    content = string
    proxied = bool
    ttl     = number
  }))
  default = []
}

variable "txt_records" {
  description = "List of TXT records"
  type = list(object({
    name    = string
    content = string
    ttl     = number
  }))
  default = []
}

variable "srv_records" {
  description = "List of SRV records"
  type = list(object({
    service  = string # e.g. "_minecraft"
    proto    = string # e.g. "_tcp"
    priority = number
    weight   = number
    port     = number
    target   = string
    ttl      = number
  }))
  default = []
}
```

- [ ] **Step 2: Create `modules/zone/outputs.tf`**

```hcl
output "zone_id" {
  description = "Cloudflare zone ID"
  value       = cloudflare_zone.this.id
}

output "zone_name" {
  description = "Domain name"
  value       = cloudflare_zone.this.name
}
```

- [ ] **Step 3: Commit**

```bash
git add providers/cloudflare/modules/zone/variables.tf providers/cloudflare/modules/zone/outputs.tf
git commit -m "feat(cloudflare): add zone module variables and outputs"
```

---

### Task 3: Zone module — main resources

**Files:**
- Create: `providers/cloudflare/modules/zone/main.tf`

- [ ] **Step 1: Create `modules/zone/main.tf`**

```hcl
resource "cloudflare_zone" "this" {
  name    = var.zone_name
  account = { id = var.account_id }
}

resource "cloudflare_dns_record" "a" {
  for_each = { for r in var.a_records : "${r.name}:${r.content}" => r }

  zone_id = cloudflare_zone.this.id
  type    = "A"
  name    = each.value.name
  content = each.value.content
  proxied = each.value.proxied
  ttl     = each.value.ttl
}

resource "cloudflare_dns_record" "mx" {
  for_each = { for r in var.mx_records : "${r.name}:${r.content}" => r }

  zone_id  = cloudflare_zone.this.id
  type     = "MX"
  name     = each.value.name
  content  = each.value.content
  priority = each.value.priority
  ttl      = each.value.ttl
}

resource "cloudflare_dns_record" "cname" {
  for_each = { for r in var.cname_records : r.name => r }

  zone_id = cloudflare_zone.this.id
  type    = "CNAME"
  name    = each.value.name
  content = each.value.content
  proxied = each.value.proxied
  ttl     = each.value.ttl
}

resource "cloudflare_dns_record" "txt" {
  for_each = { for r in var.txt_records : "${r.name}:${r.content}" => r }

  zone_id = cloudflare_zone.this.id
  type    = "TXT"
  name    = each.value.name
  content = each.value.content
  ttl     = each.value.ttl
}

resource "cloudflare_dns_record" "srv" {
  for_each = { for r in var.srv_records : "${r.service}.${r.proto}:${r.port}" => r }

  zone_id  = cloudflare_zone.this.id
  type     = "SRV"
  name     = "${each.value.service}.${each.value.proto}"
  priority = each.value.priority
  ttl      = each.value.ttl
  data = {
    weight = each.value.weight
    port   = each.value.port
    target = each.value.target
  }
}
```

- [ ] **Step 2: Validate the module**

```bash
cd providers/cloudflare
terraform fmt -recursive
terraform validate
```

Expected: `Success! The configuration is valid.`

Note: `terraform validate` will fail at this point because the root module has no `zones.tf` or `main.tf` yet — that's fine. Validate just the module:

```bash
cd providers/cloudflare/modules/zone
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add providers/cloudflare/modules/zone/main.tf
git commit -m "feat(cloudflare): add zone module main — cloudflare_zone and cloudflare_dns_record resources"
```

---

### Task 4: Root zones.tf and main.tf

**Files:**
- Create: `providers/cloudflare/zones.tf`
- Create: `providers/cloudflare/main.tf`

- [ ] **Step 1: Create `zones.tf` with your first domain**

Replace `your-domain.com` with your actual domain. Fill in your real DNS records — check the current records in Cloudflare dashboard to match exactly.

```hcl
locals {
  zones = {
    "your-domain.com" = {
      a_records = [
        # NOTE: home.your-domain.com is excluded — managed by favonia/cloudflare-ddns
        { name = "@", content = "1.2.3.4", proxied = true, ttl = 1 },
      ]
      mx_records = []
      cname_records = []
      txt_records   = []
      srv_records   = []
    }
  }
}
```

Note: `ttl = 1` means "automatic" in Cloudflare — correct for proxied records. Non-proxied records should use an explicit TTL (e.g. `300`).

- [ ] **Step 2: Create `main.tf`**

```hcl
module "zones" {
  for_each = local.zones
  source   = "./modules/zone"

  zone_name     = each.key
  account_id    = var.account_id
  a_records     = lookup(each.value, "a_records", [])
  mx_records    = lookup(each.value, "mx_records", [])
  cname_records = lookup(each.value, "cname_records", [])
  txt_records   = lookup(each.value, "txt_records", [])
  srv_records   = lookup(each.value, "srv_records", [])
}
```

- [ ] **Step 3: Validate the complete root**

```bash
cd providers/cloudflare
terraform fmt -recursive
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 4: Commit**

```bash
git add providers/cloudflare/zones.tf providers/cloudflare/main.tf
git commit -m "feat(cloudflare): add zones.tf and root main.tf with for_each module"
```

---

### Task 5: Scaffold script

**Files:**
- Create: `scripts/create-cloudflare-zone.sh`

- [ ] **Step 1: Create `scripts/create-cloudflare-zone.sh`**

```bash
#!/usr/bin/env bash
# Usage: ./scripts/create-cloudflare-zone.sh <domain>
#
# Appends a new zone stub to providers/cloudflare/zones.tf.
# Does not modify any other files — run terraform import after.
#
# Example:
#   ./scripts/create-cloudflare-zone.sh example.com

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZONES_FILE="$REPO_ROOT/providers/cloudflare/zones.tf"

# ── Validate args ──────────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <domain>"
  echo "  domain: domain name to add (e.g. example.com)"
  exit 1
fi

DOMAIN="$1"

# Basic domain format check (must contain a dot, no spaces, no slashes)
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "Error: '$DOMAIN' does not look like a valid domain name"
  exit 1
fi

# ── Duplicate check ────────────────────────────────────────────────────────────
if grep -q "\"$DOMAIN\"" "$ZONES_FILE"; then
  echo "Error: '$DOMAIN' already exists in $ZONES_FILE"
  exit 1
fi

# ── Append zone stub ───────────────────────────────────────────────────────────
# Remove the closing brace of the locals block, append the new zone, re-close.
# zones.tf ends with two closing braces: one for the zone map, one for locals {}.
# We insert before the final closing brace of the map.

SLUG="${DOMAIN//./-}"

# Strip trailing closing braces, append zone, re-add braces
CONTENT="$(head -n -2 "$ZONES_FILE")"

cat > "$ZONES_FILE" <<EOF
$CONTENT

    "$DOMAIN" = {
      a_records     = []
      mx_records    = []
      cname_records = []
      txt_records   = []
      srv_records   = []
    }
  }
}
EOF

echo ""
echo "Added '$DOMAIN' to $ZONES_FILE"
echo ""
echo "Next steps:"
echo ""
echo "  1. Fill in DNS records for '$DOMAIN' in providers/cloudflare/zones.tf"
echo ""
echo "  2. cd providers/cloudflare"
echo "     terraform init -backend-config=\"bucket=tapshalkar-com-tfstate\""
echo ""
echo "  3. Get your Cloudflare zone ID from the dashboard, then import:"
echo "     terraform import 'module.zones[\"$DOMAIN\"].cloudflare_zone.this' <ZONE_ID>"
echo ""
echo "  4. terraform plan"
echo "     Review the plan — only record diffs should appear, not the zone itself."
echo ""
echo "  5. terraform apply"
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x scripts/create-cloudflare-zone.sh
```

- [ ] **Step 3: Smoke-test the script (dry run)**

```bash
# Test validation — bad domain should error
./scripts/create-cloudflare-zone.sh "not-a-domain" 2>&1 || true

# Test duplicate detection — add your real domain a second time (should error)
./scripts/create-cloudflare-zone.sh "your-domain.com" 2>&1 || true
```

Expected for bad domain: `Error: 'not-a-domain' does not look like a valid domain name`
Expected for duplicate: `Error: 'your-domain.com' already exists in ...zones.tf`

- [ ] **Step 4: Commit**

```bash
git add scripts/create-cloudflare-zone.sh
git commit -m "feat(cloudflare): add create-cloudflare-zone.sh scaffold script"
```

---

### Task 6: Init, import, and verify

This task brings the first domain's zone into Terraform state and verifies plan shows no drift.

**Prerequisites:** You need your Cloudflare zone ID (visible in the Cloudflare dashboard sidebar for your domain) and your API token.

- [ ] **Step 1: Create `terraform.tfvars` (gitignored)**

```bash
cat > providers/cloudflare/terraform.tfvars <<'EOF'
api_token  = "your-cloudflare-api-token"
account_id = "your-cloudflare-account-id"
EOF
```

- [ ] **Step 2: Create `backend.hcl` (gitignored)**

```bash
cat > providers/cloudflare/backend.hcl <<'EOF'
bucket = "tapshalkar-com-tfstate"
EOF
```

- [ ] **Step 3: Init**

```bash
cd providers/cloudflare
terraform init -backend-config="backend.hcl"
```

Expected: `Terraform has been successfully initialized!`

- [ ] **Step 4: Import the zone**

Replace `your-domain.com` with your actual domain and `<ZONE_ID>` with the zone ID from Cloudflare dashboard.

```bash
terraform import 'module.zones["your-domain.com"].cloudflare_zone.this' <ZONE_ID>
```

Expected: `Import successful!`

- [ ] **Step 5: Import individual DNS records**

For each existing DNS record that is in `zones.tf`, import it so Terraform doesn't try to create duplicates. Get record IDs from Cloudflare dashboard (or API). Format is `<zone_id>/<record_id>`.

Example for an A record at `@`:
```bash
terraform import 'module.zones["your-domain.com"].cloudflare_dns_record.a["@:1.2.3.4"]' '<ZONE_ID>/<RECORD_ID>'
```

Example for an MX record:
```bash
terraform import 'module.zones["your-domain.com"].cloudflare_dns_record.mx["@:mail.your-domain.com"]' '<ZONE_ID>/<RECORD_ID>'
```

Repeat for each record defined in `zones.tf`. Skip the DDNS record (`home.your-domain.com`) — it should not be in `zones.tf` or state.

- [ ] **Step 6: Run plan — expect no changes**

```bash
terraform plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

If you see unexpected diffs, check that record content, TTL, proxied flag, and priority in `zones.tf` match exactly what Cloudflare shows. Adjust `zones.tf` to match, then re-run plan.

- [ ] **Step 7: Commit any zones.tf adjustments**

```bash
git add providers/cloudflare/zones.tf
git commit -m "feat(cloudflare): import first domain and reconcile zones.tf"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** Provider scaffolding ✓, zone module ✓, `for_each` root ✓, scaffold script ✓, DDNS exclusion documented in zones.tf ✓, first domain import ✓, GCS backend ✓
- [x] **Placeholder scan:** Steps use `your-domain.com` as an explicit placeholder with instructions to replace — not a vague TBD. All code blocks are complete.
- [x] **Type consistency:** `cloudflare_dns_record.a` uses `for_each` key `"${r.name}:${r.content}"` consistently with spec. SRV uses `"${r.service}.${r.proto}:${r.port}"` consistently. Module variable names match `main.tf` call sites (`a_records`, `mx_records`, etc.).
