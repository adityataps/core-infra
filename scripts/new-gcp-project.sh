#!/usr/bin/env bash
# Usage: ./scripts/new-gcp-project.sh <folder> <project-id>
#
# Creates a new GCP project root under providers/gcp/projects/<folder>/<project-id>/
# by copying the management/tapshalkar-com template and patching paths.
#
# <folder>     One of: management, personal, certs
# <project-id> The GCP project ID (must already exist in GCP)
#
# Example:
#   ./scripts/new-gcp-project.sh personal my-personal-project

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_ROOT/providers/gcp/projects/management/tapshalkar-com"
VALID_FOLDERS=("management" "personal" "certs")

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

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "✓ Project scaffolded at: providers/gcp/projects/$FOLDER/$PROJECT_ID/"
echo ""
echo "Next steps:"
echo "  1. Fill in terraform.tfvars (copy from terraform.tfvars.example):"
echo "     cp $TARGET/terraform.tfvars.example $TARGET/terraform.tfvars"
echo "     # Set project_id, project_name, billing_account, admin_user, etc."
echo ""
echo "  2. Init, import, and apply:"
echo "     cd $TARGET"
echo "     terraform init -backend-config=\"bucket=tapshalkar-com-tfstate\""
echo "     terraform import module.baseline.google_project.this projects/$PROJECT_ID"
echo "     terraform plan && terraform apply"
