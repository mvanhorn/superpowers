#!/usr/bin/env bash
# Regression test: reviewer instructions must disable paging for direct git diffs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

instruction_files=(
  "skills/subagent-driven-development/SKILL.md"
  "skills/subagent-driven-development/task-reviewer-prompt.md"
  "skills/subagent-driven-development/re-review-prompt.md"
  "skills/requesting-code-review/code-reviewer.md"
)

failures=0

check_instruction_file() {
  local file=$1
  local direct_diffs

  direct_diffs=$(grep -nE 'git diff ([^`,.]|\.\.)+' "$file" || true)
  if [[ -n "$direct_diffs" ]]; then
    echo "[FAIL] $file contains a pager-capable direct git diff command"
    echo "$direct_diffs" | sed 's/^/  /'
    failures=$((failures + 1))
  else
    echo "[PASS] $file disables paging for direct git diff commands"
  fi
}

require_instruction() {
  local file=$1
  local instruction=$2

  if grep -Fq "$instruction" "$file"; then
    echo "[PASS] $file preserves: $instruction"
  else
    echo "[FAIL] $file is missing: $instruction"
    failures=$((failures + 1))
  fi
}

for relative_file in "${instruction_files[@]}"; do
  check_instruction_file "$REPO_ROOT/$relative_file"
done

require_instruction \
  "$REPO_ROOT/skills/subagent-driven-development/SKILL.md" \
  'git --no-pager diff --stat'
require_instruction \
  "$REPO_ROOT/skills/subagent-driven-development/SKILL.md" \
  'git --no-pager diff -U10'
require_instruction \
  "$REPO_ROOT/skills/subagent-driven-development/task-reviewer-prompt.md" \
  'git --no-pager diff --stat [BASE_SHA]..[HEAD_SHA]'
require_instruction \
  "$REPO_ROOT/skills/subagent-driven-development/task-reviewer-prompt.md" \
  'git --no-pager diff [BASE_SHA]..[HEAD_SHA]'
require_instruction \
  "$REPO_ROOT/skills/subagent-driven-development/re-review-prompt.md" \
  'git --no-pager diff --stat [FIX_BASE_SHA]..[HEAD_SHA]'
require_instruction \
  "$REPO_ROOT/skills/subagent-driven-development/re-review-prompt.md" \
  'git --no-pager diff [FIX_BASE_SHA]..[HEAD_SHA]'
require_instruction \
  "$REPO_ROOT/skills/requesting-code-review/code-reviewer.md" \
  'git --no-pager diff --stat [BASE_SHA]..[HEAD_SHA]'
require_instruction \
  "$REPO_ROOT/skills/requesting-code-review/code-reviewer.md" \
  'git --no-pager diff [BASE_SHA]..[HEAD_SHA]'

# Prove the scanner rejects the regression it is intended to catch.
mutant=$(mktemp)
trap 'rm -f "$mutant"' EXIT
sed 's/git --no-pager diff/git diff/g' \
  "$REPO_ROOT/skills/requesting-code-review/code-reviewer.md" > "$mutant"
if grep -qE 'git diff ([^`,.]|\.\.)+' "$mutant"; then
  echo "[PASS] scanner rejects a pager-capable direct git diff regression"
else
  echo "[FAIL] scanner accepted a pager-capable direct git diff regression"
  failures=$((failures + 1))
fi

# review-package redirects the complete output to a file, so paging cannot stall it.
if grep -qE '^  git diff (-U10|--stat) ' \
  "$REPO_ROOT/skills/subagent-driven-development/scripts/review-package"; then
  echo "[PASS] redirected review-package diffs remain unchanged"
else
  echo "[FAIL] review-package no longer contains its redirected git diffs"
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  exit 1
fi
