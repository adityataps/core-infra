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
