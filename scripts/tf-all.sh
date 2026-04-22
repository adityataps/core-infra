#!/usr/bin/env bash
# Usage: scripts/tf-all.sh <plan|apply> [--auto-approve|<make-target>]
#
#   plan                   Preview all modules (make target: all)
#   plan ci-plan           Preview CI-scoped modules only (make target: ci-plan)
#   apply                  Apply all modules, prompting per module
#   apply --auto-approve   Apply all modules without prompting
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Parse args ────────────────────────────────────────────────────────────────
CMD="${1:-}"
AUTO_APPROVE=0
MAKE_TARGET="all"

if [[ "$CMD" == "apply" && "${2:-}" == "--auto-approve" ]]; then
  AUTO_APPROVE=1
elif [[ "$CMD" == "plan" && -n "${2:-}" ]]; then
  MAKE_TARGET="${2}"
fi

if [[ "$CMD" != "plan" && "$CMD" != "apply" ]]; then
  echo "Usage: $0 <plan|apply> [--auto-approve|<make-target>]"
  echo ""
  echo "  plan                   Preview all modules"
  echo "  plan ci-plan           Preview CI-scoped modules only"
  echo "  apply                  Apply all modules, prompting per module"
  echo "  apply --auto-approve   Apply all modules without prompting"
  exit 1
fi

# ── Progress tracking ─────────────────────────────────────────────────────────
PROGRESS_DIR=$(mktemp -d /tmp/tf-progress.XXXXXX)
trap 'rm -rf "$PROGRESS_DIR"' EXIT

# Derive total dynamically so it stays correct for any make target
TOTAL_MODULES=$(make --dry-run "$MAKE_TARGET" CMD=plan 2>/dev/null | grep -c 'tf-module\.sh' || echo 0)

printf '0'                   > "$PROGRESS_DIR/counter"
printf '%s' "$TOTAL_MODULES" > "$PROGRESS_DIR/total"
touch "$PROGRESS_DIR/results"

export TF_PROGRESS_DIR="$PROGRESS_DIR"

# ── Run ───────────────────────────────────────────────────────────────────────
cd "$REPO_ROOT"
set +e
# -k (keep going) in plan mode: tf-module.sh exits 0 for "changes detected" so
# Make prerequisites are never broken by pending diffs. Apply mode stays
# fail-fast — downstream modules depend on upstream state being applied first.
if [[ "$CMD" == "plan" ]]; then
  make -k "$MAKE_TARGET" CMD="$CMD" AUTO_APPROVE="$AUTO_APPROVE"
else
  make "$MAKE_TARGET" CMD="$CMD" AUTO_APPROVE="$AUTO_APPROVE"
fi
MAKE_EXIT=$?
set -e

# ── Synthesize exit from results (plan mode only) ─────────────────────────────
# tf-module.sh exits 0 for both clean and drift to keep Make deps intact.
# Re-derive the correct signal here: 1=error, 2=drift, 0=all clean.
if [[ "$CMD" == "plan" ]]; then
  if grep -q '^✗' "$PROGRESS_DIR/results" 2>/dev/null; then
    MAKE_EXIT=1
  elif grep -q '^~' "$PROGRESS_DIR/results" 2>/dev/null; then
    MAKE_EXIT=2
  else
    MAKE_EXIT=0
  fi
fi

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
