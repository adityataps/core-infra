#!/usr/bin/env bash
# Usage: ./scripts/create-gcp-project.sh <folder> <project-id>
#
# Creates a new GCP project root under providers/gcp/projects/<folder>/<project-id>/
# by copying the management/tapshalkar-com template, patching paths, and
# generating a terraform.tfvars with known values pre-filled.
#
# <folder>     One of: management, personal, certs
# <project-id> The GCP project ID (must already exist in GCP)
#
# Example:
#   ./scripts/create-gcp-project.sh personal my-personal-project

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_ROOT/providers/gcp/projects/management/tapshalkar-com"
VALID_FOLDERS=("management" "personal" "certs")
GITHUB_REPO="adityataps/core-infra"
ADMIN_USER="aditya@tapshalkar.com"
MANAGEMENT_PROJECT_ID="tapshalkar-com"
STATE_BUCKET="tapshalkar-com-tfstate"

# ── Validate args ──────────────────────────────────────────────────────────────
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <folder> <project-id>"
  echo "  folder:     one of: ${VALID_FOLDERS[*]}"
  echo "  project-id: GCP project ID (must already exist)"
  exit 1
fi

FOLDER="$1"
PROJECT_ID="$2"
TARGET="$REPO_ROOT/providers/gcp/projects/$FOLDER/$PROJECT_ID"

# Validate folder
if [[ ! " ${VALID_FOLDERS[*]} " =~ " $FOLDER " ]]; then
  echo "Error: folder must be one of: ${VALID_FOLDERS[*]}"
  exit 1
fi

# Prevent overwriting
if [[ -d "$TARGET" ]]; then
  echo "Error: $TARGET already exists"
  exit 1
fi

# ── Derive project name from project-id ───────────────────────────────────────
# e.g. "tapshalkar-com-sandbox" → "Tapshalkar Com Sandbox"
PROJECT_NAME="$(echo "$PROJECT_ID" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')"

# ── Copy template ──────────────────────────────────────────────────────────────
echo "Creating $TARGET from template..."
cp -r "$TEMPLATE" "$TARGET"

# Remove files that should not be copied
rm -rf "$TARGET/.terraform" "$TARGET/.terraform.lock.hcl" "$TARGET/terraform.tfvars" "$TARGET/README.md"

# ── Patch backend.tf prefix ───────────────────────────────────────────────────
sed -i '' \
  "s|prefix = \"gcp/projects/management/tapshalkar-com\"|prefix = \"gcp/projects/$FOLDER/$PROJECT_ID\"|" \
  "$TARGET/backend.tf"

# ── Patch main.tf folder_id output reference ──────────────────────────────────
FOLDER_OUTPUT="${FOLDER}_folder_resource_name"
sed -i '' \
  "s|outputs\.management_folder_resource_name|outputs.$FOLDER_OUTPUT|" \
  "$TARGET/main.tf"

# ── Non-management patches (Python for reliable multiline editing) ────────────
if [[ "$FOLDER" != "management" ]]; then
  python3 - "$TARGET/main.tf" "$STATE_BUCKET" "$MANAGEMENT_PROJECT_ID" <<'PYEOF'
import sys, re

path, state_bucket, mgmt_project = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(path).read()

# 1. billing_project: route quota through management project
content = content.replace(
    'billing_project       = var.project_id',
    'billing_project       = var.management_project_id'
)

# 2. billing_account arg: read from management remote state
content = content.replace(
    'billing_account               = var.billing_account',
    'billing_account               = data.terraform_remote_state.management.outputs.billing_account_id'
)

# 3. Append management remote state block after the closing } of gcp_org block
mgmt_block = f'''
data "terraform_remote_state" "management" {{
  backend = "gcs"
  config = {{
    bucket = "{state_bucket}"
    prefix = "gcp/projects/management/{mgmt_project}"
  }}
}}'''
content = re.sub(
    r'(data "terraform_remote_state" "gcp_org" \{.*?\n\})\n',
    r'\1\n' + mgmt_block + '\n',
    content,
    flags=re.DOTALL
)

open(path, 'w').write(content)
PYEOF

  python3 - "$TARGET/variables.tf" "$MANAGEMENT_PROJECT_ID" <<'PYEOF'
import sys, re

path, mgmt_project = sys.argv[1], sys.argv[2]
content = open(path).read()

# 1. Remove billing_account variable block
# Outer } is unindented (\n}\n\n), inner validation } is indented (\n  })
content = re.sub(
    r'variable "billing_account" \{.*?\n\}\n\n',
    '',
    content,
    flags=re.DOTALL
)

# 2. Prepend management_project_id variable
mgmt_var = f'''variable "management_project_id" {{
  type        = string
  description = "Project ID of the management project, used as billing_project for API quota."
  default     = "{mgmt_project}"
}}

'''
content = mgmt_var + content

open(path, 'w').write(content)
PYEOF
fi

# ── Generate terraform.tfvars ─────────────────────────────────────────────────
if [[ "$FOLDER" == "management" ]]; then
  cat > "$TARGET/terraform.tfvars" <<EOF
project_id      = "$PROJECT_ID"
project_name    = "$PROJECT_NAME"
billing_account = "XXXXXX-XXXXXX-XXXXXX" # TODO: fill in billing account ID
admin_user      = "$ADMIN_USER"
region          = "us-central1"
budget_amount   = 20
github_repo     = "$GITHUB_REPO"

labels = {
  env          = "$FOLDER"
  owner        = "aditya"
  "managed-by" = "terraform"
}
EOF
else
  cat > "$TARGET/terraform.tfvars" <<EOF
project_id    = "$PROJECT_ID"
project_name  = "$PROJECT_NAME"
admin_user    = "$ADMIN_USER"
region        = "us-central1"
budget_amount = 20
github_repo   = "$GITHUB_REPO"

labels = {
  env          = "$FOLDER"
  owner        = "aditya"
  "managed-by" = "terraform"
}
EOF
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "✓ Project scaffolded at: providers/gcp/projects/$FOLDER/$PROJECT_ID/"
echo "✓ terraform.tfvars generated (review before applying)"
echo ""
echo "Next steps:"
echo "  1. Review and adjust if needed:"
echo "     \$EDITOR $TARGET/terraform.tfvars"
echo ""
echo "  2. Init, import, and apply:"
echo "     cd $TARGET"
echo "     terraform init -backend-config=\"bucket=$STATE_BUCKET\""
echo "     terraform import module.baseline.google_project.this projects/$PROJECT_ID"
echo "     terraform plan && terraform apply"
