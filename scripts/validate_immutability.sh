#!/usr/bin/env bash
# validate_immutability.sh
# Blocks a PR if any modified/deleted .sql file in supabase/phase_1/
# is already recorded in phase_1_registry.yml (i.e. already deployed).
#
# Logic:
#   1. Get the list of changed files in this PR (vs master)
#   2. For each changed .sql file, check if its name appears in the registry
#   3. If yes → it has already been deployed → fail and explain
#
# A file that is only ADDED (new) is fine.
# A file that is MODIFIED or DELETED after deployment is not allowed.

REGISTRY="supabase/phase_1_registry.yml"
ERRORS=0

echo "=== Immutability check for deployed phase_1 files ==="
echo ""

# Registry must exist for this check to be meaningful
if [ ! -f "$REGISTRY" ]; then
  echo "  Registry not found — no deployed files to check against."
  echo "  All files are considered new. Check passed."
  exit 0
fi

# Get files changed in this PR compared to master
# GITHUB_BASE_REF is set by GitHub Actions on pull_request events
BASE="${GITHUB_BASE_REF:-master}"
echo "  Comparing against base branch: $BASE"
echo ""

# List modified or deleted .sql files (not purely added ones)
# M = modified, D = deleted, R = renamed
changed_files=$(git diff --name-only --diff-filter=MDR "origin/${BASE}...HEAD" -- 'supabase/phase_1/*.sql' 2>/dev/null || true)

if [ -z "$changed_files" ]; then
  echo "  No modifications to existing .sql files detected."
  echo ""
  echo "=========================================="
  echo "  IMMUTABILITY CHECK PASSED"
  echo "=========================================="
  exit 0
fi

echo "  Modified/deleted .sql files in this PR:"
echo "$changed_files" | sed 's/^/    - /'
echo ""

echo "  Checking against registry..."
echo ""

while IFS= read -r filepath; do
  [ -z "$filepath" ] && continue
  filename=$(basename "$filepath")

  if grep -q "name: \"${filename}\"" "$REGISTRY" 2>/dev/null; then
    echo "  [FAIL] $filename"
    echo "         This file has already been deployed and is recorded in the registry."
    echo "         Deployed files are immutable — do not modify them."
    echo "         To make changes, create a NEW file, e.g.:"
    echo "           supabase/phase_1/${filename%.sql}_v2.sql"
    echo ""
    ERRORS=$((ERRORS + 1))
  else
    echo "  [PASS] $filename — not yet deployed, modification allowed"
  fi

done <<< "$changed_files"

if [ "$ERRORS" -gt 0 ]; then
  echo "=========================================="
  echo "  IMMUTABILITY CHECK FAILED"
  echo "  $ERRORS deployed file(s) were modified."
  echo ""
  echo "  Rule: Once a .sql file is deployed and"
  echo "  recorded in phase_1_registry.yml it must"
  echo "  never be changed. Add a new file instead."
  echo "=========================================="
  exit 1
fi

echo "=========================================="
echo "  IMMUTABILITY CHECK PASSED"
echo "=========================================="
exit 0
