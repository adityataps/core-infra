#!/usr/bin/env bash
# Usage: ./scripts/create-aws-account.sh <ou> <account-name>
#
# Scaffolds a new AWS member account into the core-infra monorepo:
#   • Creates providers/aws/accounts/<ou>/<account-name>/ with all Terraform files
#   • Adds an aws_organizations_account resource, variables, and output to aws/org
#   • Wires the account into management centralized budgets
#   • Extends providers/github/ with a new OIDC role ARN secret
#
# <ou>           OU to place the account in: certs | projects | personal | management
# <account-name> Slug for the account (lowercase, hyphens OK — e.g. "certs-3")
#
# The "management" OU is created automatically in org/main.tf on first use.
#
# Example:
#   ./scripts/create-aws-account.sh projects my-new-project
#   ./scripts/create-aws-account.sh certs certs-3
#   ./scripts/create-aws-account.sh management security-audit

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALID_OUS=("certs" "projects" "personal" "management")
STATE_BUCKET="tapshalkar-com-tfstate"

# ── Validate args ──────────────────────────────────────────────────────────────
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <ou> <account-name>"
  echo "  ou:           one of: ${VALID_OUS[*]}"
  echo "  account-name: slug for the account (e.g. certs-3, my-project)"
  exit 1
fi

OU="$1"
ACCOUNT_NAME="$2"
TARGET="$REPO_ROOT/providers/aws/accounts/$OU/$ACCOUNT_NAME"

# Validate OU
if [[ ! " ${VALID_OUS[*]} " =~ " $OU " ]]; then
  echo "Error: OU must be one of: ${VALID_OUS[*]}"
  exit 1
fi

# Validate account name (lowercase, alphanumeric + hyphens, must start with a letter)
if [[ ! "$ACCOUNT_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: account-name must be lowercase alphanumeric with hyphens (e.g. my-project)"
  exit 1
fi

# Ensure the OU resource exists in org/main.tf — create it automatically if missing.
# This is the normal path for "management" (not yet in org) and a safety check for others.
ORG_MAIN="$REPO_ROOT/providers/aws/org/main.tf"
ORG_OUTPUTS="$REPO_ROOT/providers/aws/org/outputs.tf"

if ! grep -q "organizational_unit.*\"$OU\"" "$ORG_MAIN"; then
  echo "OU '$OU' not found in org/main.tf — creating it now..."
  python3 - "$ORG_MAIN" "$OU" <<'PYEOF'
import sys, re

path, ou = sys.argv[1], sys.argv[2]
content = open(path).read()

new_ou_block = f'''
resource "aws_organizations_organizational_unit" "{ou}" {{
  name      = "{ou}"
  parent_id = data.aws_organizations_organization.this.roots[0].id
}}
'''

# Insert before the first aws_organizations_account resource to keep OUs grouped
match = re.search(r'\nresource "aws_organizations_account"', content)
if match:
    content = content[:match.start()] + '\n' + new_ou_block + content[match.start():]
else:
    content = content.rstrip('\n') + '\n' + new_ou_block

open(path, 'w').write(content)
print(f"  ✓ Added aws_organizations_organizational_unit.{ou} to org/main.tf")
PYEOF

  # Also add the OU ID output to org/outputs.tf (after the last existing OU output)
  python3 - "$ORG_OUTPUTS" "$OU" <<'PYEOF'
import sys, re

path, ou = sys.argv[1], sys.argv[2]
content = open(path).read()

new_ou_output = f'''
output "{ou}_ou_id" {{
  description = "ID of the {ou}/ OU"
  value       = aws_organizations_organizational_unit.{ou}.id
}}
'''

if f'output "{ou}_ou_id"' not in content:
    # Insert after the last _ou_id output, before the first _account_id output
    match = re.search(r'\noutput "\w+_account_id"', content)
    if match:
        content = content[:match.start()] + '\n' + new_ou_output + content[match.start():]
    else:
        content = content.rstrip('\n') + '\n' + new_ou_output
    open(path, 'w').write(content)
    print(f"  ✓ Added {ou}_ou_id output to org/outputs.tf")
PYEOF
fi

# Prevent overwriting
if [[ -d "$TARGET" ]]; then
  echo "Error: $TARGET already exists"
  exit 1
fi

# ── Derive identifiers ─────────────────────────────────────────────────────────
# Terraform resource/variable name: hyphens → underscores
RESOURCE_NAME="${ACCOUNT_NAME//-/_}"
# GitHub secret suffix: uppercase of resource name
SECRET_SUFFIX="$(echo "$RESOURCE_NAME" | tr '[:lower:]' '[:upper:]')"

echo "Scaffolding AWS account: $ACCOUNT_NAME"
echo "  OU:                 $OU"
echo "  Terraform resource: aws_organizations_account.$RESOURCE_NAME"
echo "  GitHub secret:      AWS_${SECRET_SUFFIX}_ROLE_ARN"
echo ""

# ── 1. Create account root directory ──────────────────────────────────────────
mkdir -p "$TARGET"

# versions.tf — assume_role into the new account via OrganizationAccountAccessRole
cat > "$TARGET/versions.tf" <<EOF
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::\${var.account_id}:role/OrganizationAccountAccessRole"
  }
}
EOF

# backend.tf
cat > "$TARGET/backend.tf" <<EOF
terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/$OU/$ACCOUNT_NAME"
  }
}
EOF

# variables.tf
cat > "$TARGET/variables.tf" <<EOF
variable "account_id" {
  type        = string
  description = "AWS account ID of the $ACCOUNT_NAME account. Get from: terraform output -raw ${RESOURCE_NAME}_account_id (in providers/aws/org/)"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}
EOF

# main.tf — reads github remote state, calls baseline module
# Module source is always ../../../modules/baseline (3 levels: accounts/<ou>/<name>)
cat > "$TARGET/main.tf" <<EOF
data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "$STATE_BUCKET"
    prefix = "github"
  }
}

module "baseline" {
  source = "../../../modules/baseline"

  account_name = "$ACCOUNT_NAME"
  region       = var.region
  github_repo  = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
}
EOF

# outputs.tf
cat > "$TARGET/outputs.tf" <<EOF
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication ($ACCOUNT_NAME account)"
  value       = module.baseline.github_actions_role_arn
}
EOF

# terraform.tfvars.example
cat > "$TARGET/terraform.tfvars.example" <<EOF
# Get account_id from: cd providers/aws/org && terraform output ${RESOURCE_NAME}_account_id
account_id = "123456789012"
region     = "us-east-1"
EOF

echo "✓ Account root files written to providers/aws/accounts/$OU/$ACCOUNT_NAME/"

# ── 2. Patch providers/aws/org/main.tf ────────────────────────────────────────
python3 - "$ORG_MAIN" "$RESOURCE_NAME" "$OU" <<'PYEOF'
import sys

path, resource_name, ou = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(path).read()

new_block = f'''
resource "aws_organizations_account" "{resource_name}" {{
  name              = var.{resource_name}_account_name
  email             = var.{resource_name}_account_email
  parent_id         = aws_organizations_organizational_unit.{ou}.id
  close_on_deletion = true
}}
'''

if f'resource "aws_organizations_account" "{resource_name}"' not in content:
    content = content.rstrip('\n') + '\n' + new_block
    open(path, 'w').write(content)
    print(f"✓ Added aws_organizations_account.{resource_name} to org/main.tf")
else:
    print(f"⚠ aws_organizations_account.{resource_name} already present in org/main.tf — skipping")
PYEOF

# ── 3. Patch providers/aws/org/variables.tf ───────────────────────────────────
ORG_VARS="$REPO_ROOT/providers/aws/org/variables.tf"

python3 - "$ORG_VARS" "$RESOURCE_NAME" "$ACCOUNT_NAME" <<'PYEOF'
import sys

path, resource_name, account_name = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(path).read()

new_vars = f'''
variable "{resource_name}_account_name" {{
  type        = string
  description = "Display name of the {account_name} account"
}}

variable "{resource_name}_account_email" {{
  type        = string
  description = "Root email of the {account_name} account"
}}
'''

if f'variable "{resource_name}_account_name"' not in content:
    content = content.rstrip('\n') + '\n' + new_vars
    open(path, 'w').write(content)
    print(f"✓ Added {resource_name}_account_name/email variables to org/variables.tf")
else:
    print(f"⚠ {resource_name}_account_name already present in org/variables.tf — skipping")
PYEOF

# ── 4. Patch providers/aws/org/outputs.tf ─────────────────────────────────────
python3 - "$ORG_OUTPUTS" "$RESOURCE_NAME" "$ACCOUNT_NAME" <<'PYEOF'
import sys

path, resource_name, account_name = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(path).read()

new_output = f'''
output "{resource_name}_account_id" {{
  description = "AWS account ID of the {account_name} account"
  value       = aws_organizations_account.{resource_name}.id
}}
'''

if f'output "{resource_name}_account_id"' not in content:
    content = content.rstrip('\n') + '\n' + new_output
    open(path, 'w').write(content)
    print(f"✓ Added {resource_name}_account_id output to org/outputs.tf")
else:
    print(f"⚠ {resource_name}_account_id already present in org/outputs.tf — skipping")
PYEOF

# ── 5. Patch management/budgets.tf ────────────────────────────────────────────
MGMT_BUDGETS="$REPO_ROOT/providers/aws/accounts/management/budgets.tf"

python3 - "$MGMT_BUDGETS" "$RESOURCE_NAME" <<'PYEOF'
import sys, re

path, resource_name = sys.argv[1], sys.argv[2]
content = open(path).read()

if resource_name in content:
    print(f"⚠ {resource_name} already present in management/budgets.tf — skipping")
    sys.exit(0)

# Insert new entry into the budgeted_accounts map (before its closing brace).
# The map closes with a line that is exactly '  }' (2-space indent).
new_entry = f'    {resource_name:<12} = data.terraform_remote_state.aws_org.outputs.{resource_name}_account_id\n'

content = re.sub(
    r'(  budgeted_accounts = \{.*?)(  \})',
    lambda m: m.group(1) + new_entry + '  }',
    content,
    count=1,
    flags=re.DOTALL
)

open(path, 'w').write(content)
print(f"✓ Added {resource_name} to budgeted_accounts in management/budgets.tf")
PYEOF

# ── 6. Patch management/variables.tf ──────────────────────────────────────────
MGMT_VARS="$REPO_ROOT/providers/aws/accounts/management/variables.tf"

python3 - "$MGMT_VARS" "$RESOURCE_NAME" <<'PYEOF'
import sys, re

path, resource_name = sys.argv[1], sys.argv[2]
content = open(path).read()

if f'"{resource_name}"' in content:
    print(f"⚠ {resource_name} already present in management/variables.tf — skipping")
    sys.exit(0)

# 1. Add to the default map (before its closing brace)
content = re.sub(
    r'(  default = \{.*?)(\n  \})',
    lambda m: m.group(1) + f'\n    {resource_name} = 10' + m.group(2),
    content,
    count=1,
    flags=re.DOTALL
)

# 2. Extend the validation condition's key list
#    Matches: [for k in ["a", "b"] : ...]  →  [for k in ["a", "b", "new"] : ...]
content = re.sub(
    r'(condition\s+=\s+alltrue\(\[for k in \[)(.*?)(\] :)',
    lambda m: m.group(1) + m.group(2).rstrip('"') + f'", "{resource_name}"' + m.group(3),
    content,
    count=1
)

# 3. Extend the validation error_message key list
content = re.sub(
    r'(error_message = "budget_amounts must contain keys: )(.*?)("\.)',
    lambda m: m.group(1) + m.group(2) + f', {resource_name}' + m.group(3),
    content,
    count=1
)

open(path, 'w').write(content)
print(f"✓ Added {resource_name} to budget_amounts in management/variables.tf")
PYEOF

# ── 7. Patch providers/github/main.tf ─────────────────────────────────────────
GITHUB_MAIN="$REPO_ROOT/providers/github/main.tf"

python3 - "$GITHUB_MAIN" "$RESOURCE_NAME" "$OU" "$ACCOUNT_NAME" "$STATE_BUCKET" <<'PYEOF'
import sys, re

path, resource_name, ou, account_name, state_bucket = \
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
content = open(path).read()
secret_name = f"AWS_{resource_name.upper()}_ROLE_ARN"
backend_prefix = f"aws/accounts/{ou}/{account_name}"

new_state_block = f'''
data "terraform_remote_state" "aws_{resource_name}" {{
  backend = "gcs"
  config = {{
    bucket = "{state_bucket}"
    prefix = "{backend_prefix}"
  }}
}}
'''

new_secret_block = f'''
resource "github_actions_secret" "aws_{resource_name}_role_arn" {{
  repository      = data.github_repository.core_infra.name
  secret_name     = "{secret_name}"
  plaintext_value = data.terraform_remote_state.aws_{resource_name}.outputs.github_actions_role_arn
}}
'''

changed = False

# Insert remote state before the "AWS Actions secrets" comment section
if f'data "terraform_remote_state" "aws_{resource_name}"' not in content:
    content = re.sub(
        r'(# ── AWS Actions secrets ─+)',
        new_state_block.rstrip('\n') + '\n\n' + r'\1',
        content,
        count=1
    )
    changed = True
    print(f"✓ Added aws_{resource_name} remote state to github/main.tf")
else:
    print(f"⚠ aws_{resource_name} remote state already present — skipping")

# Insert secret before the "AWS Actions variables" comment (or at end of file)
if f'resource "github_actions_secret" "aws_{resource_name}_role_arn"' not in content:
    if '# ── AWS Actions variables' in content:
        content = re.sub(
            r'(# ── AWS Actions variables ─+)',
            new_secret_block.rstrip('\n') + '\n\n' + r'\1',
            content,
            count=1
        )
    else:
        content = content.rstrip('\n') + '\n' + new_secret_block
    changed = True
    print(f"✓ Added aws_{resource_name}_role_arn secret to github/main.tf")
else:
    print(f"⚠ aws_{resource_name}_role_arn already present — skipping")

if changed:
    open(path, 'w').write(content)
PYEOF

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "✓ Account '$ACCOUNT_NAME' scaffolded. Files changed:"
echo "  + providers/aws/accounts/$OU/$ACCOUNT_NAME/  (new)"
echo "  ~ providers/aws/org/main.tf"
echo "  ~ providers/aws/org/variables.tf"
echo "  ~ providers/aws/org/outputs.tf"
echo "  ~ providers/aws/accounts/management/budgets.tf"
echo "  ~ providers/aws/accounts/management/variables.tf"
echo "  ~ providers/github/main.tf"
echo ""
echo "Next steps:"
echo ""
echo "  1. Fill in org/terraform.tfvars (add name + email for $ACCOUNT_NAME):"
echo "     \$EDITOR $REPO_ROOT/providers/aws/org/terraform.tfvars"
echo ""
echo "  2. Apply providers/aws/org/ — import first if account already exists in AWS:"
echo "     cd $REPO_ROOT/providers/aws/org"
echo "     terraform init -backend-config=\"bucket=$STATE_BUCKET\""
echo "     terraform import aws_organizations_account.$RESOURCE_NAME <EXISTING_ACCOUNT_ID>  # if needed"
echo "     terraform plan && terraform apply"
echo ""
echo "  3. Create account tfvars from example (use org output for account_id):"
echo "     cd $REPO_ROOT/providers/aws/org && terraform output ${RESOURCE_NAME}_account_id"
echo "     cp $TARGET/terraform.tfvars.example $TARGET/terraform.tfvars"
echo "     \$EDITOR $TARGET/terraform.tfvars"
echo ""
echo "  4. Apply the account root (sets up OIDC for GitHub Actions):"
echo "     cd $TARGET"
echo "     terraform init -backend-config=\"bucket=$STATE_BUCKET\""
echo "     terraform plan && terraform apply"
echo ""
echo "  5. Add $RESOURCE_NAME to budget_amounts in management/terraform.tfvars, then apply:"
echo "     \$EDITOR $REPO_ROOT/providers/aws/accounts/management/terraform.tfvars"
echo "     cd $REPO_ROOT/providers/aws/accounts/management"
echo "     terraform plan && terraform apply"
echo ""
echo "  6. Apply providers/github/ to publish AWS_${SECRET_SUFFIX}_ROLE_ARN to GitHub Actions:"
echo "     cd $REPO_ROOT/providers/github"
echo "     terraform plan && terraform apply"
