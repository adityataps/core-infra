#!/usr/bin/env bash
# Usage: scripts/tf-all.sh <plan|apply> [--auto-approve]
#
#   plan                   Preview changes across all modules in dependency order
#   apply                  Apply changes, prompting per module
#   apply --auto-approve   Apply all changes without prompting
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOTAL_MODULES=15  # keep in sync with number of targets called in Makefile `all` chain

# ── Parse args ────────────────────────────────────────────────────────────────
CMD="${1:-}"
AUTO_APPROVE=0

if [[ "$CMD" == "apply" && "${2:-}" == "--auto-approve" ]]; then
  AUTO_APPROVE=1
fi

if [[ "$CMD" != "plan" && "$CMD" != "apply" ]]; then
  echo "Usage: $0 <plan|apply> [--auto-approve]"
  echo ""
  echo "  plan                   Preview changes across all modules"
  echo "  apply                  Apply changes, prompting per module"
  echo "  apply --auto-approve   Apply all changes without prompting"
  exit 1
fi

# ── Progress tracking ─────────────────────────────────────────────────────────
PROGRESS_DIR=$(mktemp -d /tmp/tf-progress.XXXXXX)
trap 'rm -rf "$PROGRESS_DIR"' EXIT

printf '0'              > "$PROGRESS_DIR/counter"
printf '%s' "$TOTAL_MODULES" > "$PROGRESS_DIR/total"
touch "$PROGRESS_DIR/results"

export TF_PROGRESS_DIR="$PROGRESS_DIR"

# ── Run ───────────────────────────────────────────────────────────────────────
cd "$REPO_ROOT"
set +e
# -k (keep going) in plan mode: continue past individual module failures so all
# modules are planned and the summary shows the full picture. Apply mode stays
# fail-fast — downstream modules depend on upstream state being applied first.
if [[ "$CMD" == "plan" ]]; then
  make -k all CMD="$CMD" AUTO_APPROVE="$AUTO_APPROVE"
else
  make all CMD="$CMD" AUTO_APPROVE="$AUTO_APPROVE"
fi
MAKE_EXIT=$?
set -e

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "Summary (%s modules)\n" "$TOTAL_MODULES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -s "$PROGRESS_DIR/results" ]]; then
  cat "$PROGRESS_DIR/results"
else
  echo "(no modules completed)"
fi
echo ""

exit $MAKE_EXIT
