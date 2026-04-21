#!/usr/bin/env bash
# Usage: scripts/tf-module.sh <cmd> <auto_approve> <module_path>
#
#   cmd           plan | apply
#   auto_approve  0 (prompt per module) | 1 (no prompt)
#   module_path   relative to repo root, e.g. providers/gcp/org
#
# Exit codes:
#   0  success (no changes for plan, applied/skipped for apply)
#   1  terraform error
#   2  drift detected (plan mode) or user aborted with 'q' (apply mode)
set -euo pipefail

CMD="$1"
AUTO_APPROVE="$2"
MODULE="$3"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_PATH="$REPO_ROOT/$MODULE"
STATE_BUCKET="tapshalkar-com-tfstate"
PROGRESS_DIR="${TF_PROGRESS_DIR:-}"

# ── Progress header ────────────────────────────────────────────────────────────
if [[ -n "$PROGRESS_DIR" ]]; then
  COUNTER=$(( $(cat "$PROGRESS_DIR/counter") + 1 ))
  printf '%s' "$COUNTER" > "$PROGRESS_DIR/counter"
  TOTAL=$(cat "$PROGRESS_DIR/total")
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "[$COUNTER/$TOTAL] $MODULE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# ── Init ──────────────────────────────────────────────────────────────────────
cd "$MODULE_PATH"
terraform init \
  -backend-config="bucket=$STATE_BUCKET" \
  -reconfigure \
  -input=false \
  -no-color 2>&1 | grep -E "^(Terraform|Error|Warning|Initializing)" || true

# ── Plan ──────────────────────────────────────────────────────────────────────
TFPLAN=$(mktemp /tmp/tf-plan.XXXXXX)
trap 'rm -f "$TFPLAN"' EXIT

if [[ "$CMD" == "plan" ]]; then
  set +e
  terraform plan -detailed-exitcode -input=false -out="$TFPLAN"
  PLAN_EXIT=$?
  set -e

  if [[ -n "$PROGRESS_DIR" ]]; then
    case $PLAN_EXIT in
      0) echo "○ no change  $MODULE" >> "$PROGRESS_DIR/results" ;;
      2) echo "~ changes    $MODULE" >> "$PROGRESS_DIR/results" ;;
      1) echo "✗ error      $MODULE" >> "$PROGRESS_DIR/results" ;;
    esac
  fi
  exit $PLAN_EXIT
fi

# ── Apply ─────────────────────────────────────────────────────────────────────
terraform plan -input=false -out="$TFPLAN"

if [[ "$AUTO_APPROVE" == "1" ]]; then
  terraform apply -input=false "$TFPLAN"
  RESULT="✓ applied    $MODULE"
else
  echo ""
  printf "Apply changes to %s? [y/s/q] " "$MODULE"
  read -r RESPONSE </dev/tty
  case "$RESPONSE" in
    y|Y)
      terraform apply -input=false "$TFPLAN"
      RESULT="✓ applied    $MODULE"
      ;;
    q|Q)
      echo "Aborted."
      exit 2
      ;;
    *)
      echo "Skipping $MODULE"
      RESULT="○ skipped    $MODULE"
      ;;
  esac
fi

[[ -n "$PROGRESS_DIR" ]] && echo "$RESULT" >> "$PROGRESS_DIR/results"
