#!/usr/bin/env bash
# Usage: ./scripts/create-aws-account.sh <ou> <account-name>
#
# Scaffolds a new AWS member account into the core-infra monorepo:
#   • Creates providers/aws/accounts/<ou>/<account-name>/ with all Terraform files
#   • Wires the account into providers/github/ with a new OIDC role ARN secret
#
# Account creation in AWS is done via the AWS CLI (see "Next steps" output).
# org/ Terraform is NOT modified — it manages OUs only.
#
# <ou>           OU to place the account in: certs | projects | personal | management
# <account-name> Slug for the account (lowercase, hyphens OK — e.g. "tapshalkar-com-dev")
#
# Example:
#   ./scripts/create-aws-account.sh personal tapshalkar-com-dev
#   ./scripts/create-aws-account.sh certs tapshalkar-com-certs-2

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALID_OUS=("certs" "projects" "personal" "management")
# shellcheck source=config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# ── Validate args ──────────────────────────────────────────────────────────────
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <ou> <account-name>"
  echo "  ou:           one of: ${VALID_OUS[*]}"
  echo "  account-name: slug for the account (e.g. tapshalkar-com-dev)"
  exit 1
fi

OU="$1"
ACCOUNT_NAME="$2"
TARGET="$REPO_ROOT/providers/aws/accounts/$OU/$ACCOUNT_NAME"

if [[ ! " ${VALID_OUS[*]} " =~ " $OU " ]]; then
  echo "Error: OU must be one of: ${VALID_OUS[*]}"
  exit 1
fi

if [[ ! "$ACCOUNT_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: account-name must be lowercase alphanumeric with hyphens (e.g. tapshalkar-com-dev)"
  exit 1
fi

if [[ -d "$TARGET" ]]; then
  echo "Error: $TARGET already exists"
  exit 1
fi

RESOURCE_NAME="${ACCOUNT_NAME//-/_}"
SECRET_SUFFIX="$(echo "$RESOURCE_NAME" | tr '[:lower:]' '[:upper:]')"

echo "Scaffolding AWS account: $ACCOUNT_NAME"
echo "  OU:             $OU"
echo "  GitHub secret:  AWS_${SECRET_SUFFIX}_ROLE_ARN"
echo ""

# ── 1. Create account root directory ──────────────────────────────────────────
mkdir -p "$TARGET"

# versions.tf — provider + backend in one block to avoid duplicate terraform{} issues
cat > "$TARGET/versions.tf" <<EOF
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "aws/accounts/$OU/$ACCOUNT_NAME"
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::\${var.account_id}:role/OrganizationAccountAccessRole"
  }
}
EOF

# variables.tf
cat > "$TARGET/variables.tf" <<EOF
variable "account_id" {
  type        = string
  description = "AWS account ID of the $ACCOUNT_NAME account (used for assume_role in versions.tf)"
}

variable "region" {
  type        = string
  description = "AWS region for this account"
  default     = "us-east-1"
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in USD for this account"
  default     = 10
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Fractional spend thresholds triggering SNS alerts (e.g. [0.5, 0.9, 1.0])"
  default     = [0.5, 0.9, 1.0]
}

variable "notification_email" {
  type        = string
  description = "Email address for budget alert SNS subscription"
}
EOF

# main.tf
cat > "$TARGET/main.tf" <<EOF
data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "$STATE_BUCKET"
    prefix = "github"
  }
}

data "terraform_remote_state" "pagerduty" {
  backend = "gcs"
  config = {
    bucket = "$STATE_BUCKET"
    prefix = "pagerduty"
  }
}

module "baseline" {
  source = "../../../modules/baseline"

  account_name              = "$ACCOUNT_NAME"
  region                    = var.region
  github_repo               = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
  budget_amount             = var.budget_amount
  budget_thresholds         = var.budget_thresholds
  notification_email        = var.notification_email
  pagerduty_integration_key = data.terraform_remote_state.pagerduty.outputs.aws_integration_key
}
EOF

# outputs.tf
cat > "$TARGET/outputs.tf" <<EOF
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication ($ACCOUNT_NAME account)"
  value       = module.baseline.github_actions_role_arn
}

output "account_id" {
  description = "AWS account ID of the $ACCOUNT_NAME account"
  value       = module.baseline.account_id
}
EOF

# terraform.tfvars.example
cat > "$TARGET/terraform.tfvars.example" <<EOF
account_id         = "123456789012"
region             = "us-east-1"
budget_amount      = 10
budget_thresholds  = [0.5, 0.9, 1.0]
notification_email = "you@example.com"
EOF

# README.md
cat > "$TARGET/README.md" <<EOF
# \`$OU/$ACCOUNT_NAME\`

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
EOF

echo "✓ Account root files written to providers/aws/accounts/$OU/$ACCOUNT_NAME/"

# ── 2. Patch providers/github/main.tf ─────────────────────────────────────────
GITHUB_MAIN="$REPO_ROOT/providers/github/main.tf"

python3 - "$GITHUB_MAIN" "$RESOURCE_NAME" "$OU" "$ACCOUNT_NAME" "$STATE_BUCKET" <<'PYEOF'
import sys, re

path, resource_name, ou, account_name, state_bucket = \
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
content = open(path).read()
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
  secret_name     = "AWS_{resource_name.upper()}_ROLE_ARN"
  plaintext_value = data.terraform_remote_state.aws_{resource_name}.outputs.github_actions_role_arn
}}
'''

changed = False

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

# ── 3. Patch Makefile + tf-all.sh ─────────────────────────────────────────────
python3 - "$REPO_ROOT/Makefile" "$REPO_ROOT/scripts/tf-all.sh" "$OU" "$ACCOUNT_NAME" <<'PYEOF'
import sys, re

makefile_path, tf_all_path, ou, account_name = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

target      = f"aws-{ou}-{account_name}"
module_path = f"providers/aws/accounts/{ou}/{account_name}"

content = open(makefile_path).read()

if target in content:
    print(f"⚠ {target} already in Makefile — skipping")
    sys.exit(0)

# 1. Add to .PHONY (before the closing "        ci-plan" line)
content = content.replace(
    '        ci-plan',
    f'        {target} \\\n        ci-plan'
)

# 2. Add to github-sync prerequisites (before its recipe line)
content = re.sub(
    r'(github-sync:.*?)(\n\t@\$\(RUN\) providers/github)',
    lambda m: m.group(1) + f' \\\n             {target}' + m.group(2),
    content,
    flags=re.DOTALL
)

# 3. Insert target block in Tier 3 section
new_block = f'\n{target}: pagerduty aws-org github-init aws-management\n\t@$(RUN) {module_path}\n'
content = content.replace('# ── Tier 2:', new_block + '# ── Tier 2:')

open(makefile_path, 'w').write(content)
print(f"✓ Added {target} to Makefile")

# 4. Increment TOTAL_MODULES in tf-all.sh
tf_all = open(tf_all_path).read()
m = re.search(r'TOTAL_MODULES=(\d+)', tf_all)
if m:
    old, new = int(m.group(1)), int(m.group(1)) + 1
    open(tf_all_path, 'w').write(tf_all.replace(f'TOTAL_MODULES={old}', f'TOTAL_MODULES={new}'))
    print(f"✓ Updated TOTAL_MODULES: {old} → {new}")
PYEOF

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "✓ '$ACCOUNT_NAME' scaffolded. Files changed:"
echo "  + providers/aws/accounts/$OU/$ACCOUNT_NAME/  (new)"
echo "  ~ providers/github/main.tf"
echo "  ~ Makefile"
echo "  ~ scripts/tf-all.sh"
echo ""
echo "Next steps:"
echo ""
echo "  1. Create the AWS account via CLI (from a session with management account credentials):"
echo "     aws organizations create-account \\"
echo "       --account-name \"<display name>\" \\"
echo "       --email \"<root-email>\" \\"
echo "       --iam-user-access-to-billing ALLOW"
echo ""
echo "     Then move it to the correct OU:"
echo "     aws organizations move-account \\"
echo "       --account-id <NEW_ACCOUNT_ID> \\"
echo "       --source-parent-id <ROOT_ID> \\"
echo "       --destination-parent-id <$(echo "$OU" | tr '[:lower:]' '[:upper:]')_OU_ID>"
echo ""
echo "     OU IDs are in: cd providers/aws/org && terraform output"
echo ""
echo "  2. Create account tfvars from example (use the account ID from step 1):"
echo "     cp $TARGET/terraform.tfvars.example $TARGET/terraform.tfvars"
echo "     \$EDITOR $TARGET/terraform.tfvars"
echo ""
echo "  3. Apply the account root (sets up OIDC + budget):"
echo "     cd $TARGET"
echo "     terraform init -backend-config=\"bucket=$STATE_BUCKET\""
echo "     terraform plan && terraform apply"
echo ""
echo "  4. Apply providers/github/ to publish AWS_${SECRET_SUFFIX}_ROLE_ARN to GitHub Actions:"
echo "     cd $REPO_ROOT/providers/github"
echo "     terraform plan && terraform apply"
