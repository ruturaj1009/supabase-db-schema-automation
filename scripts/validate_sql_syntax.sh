#!/usr/bin/env bash
# validate_sql_syntax.sh
# Validates SQL syntax of every file in supabase/phase_1/ by running each
# inside a transaction that is always rolled back — nothing is committed.
#
# Catches:
#   - Syntax errors
#   - References to non-existent tables/columns (if schema already exists)
#   - Invalid data types
#   - Malformed DDL/DML statements
#
# Requires: SUPABASE_DB_URL env var — use the CONNECTION POOLER URL from
#           Supabase → Settings → Database → Connection Pooler → Session mode
#           (port 6543). Do NOT use the direct DB URL (port 5432, IPv6 only).
# Exits 1 if any file fails — blocks PR merge.

set -euo pipefail

PHASE_DIR="supabase/phase_1"
ERRORS=0
CHECKED=0

if [ -z "${SUPABASE_DB_URL:-}" ]; then
  echo "ERROR: SUPABASE_DB_URL environment variable is not set."
  exit 1
fi

echo "=== Validating SQL syntax in $PHASE_DIR ==="
echo ""

while IFS= read -r filepath; do
  filename=$(basename "$filepath")
  CHECKED=$((CHECKED + 1))

  echo "  --> Checking: $filename"

  # Wrap the file content in a transaction that always rolls back.
  # If psql exits non-zero, the file has a syntax or semantic error.
  RESULT=$(psql "$SUPABASE_DB_URL" \
    --no-psqlrc \
    --set ON_ERROR_STOP=1 \
    --set AUTOCOMMIT=off \
    2>&1 <<SQL
BEGIN;
\i ${filepath}
ROLLBACK;
SQL
  ) && EXIT_CODE=0 || EXIT_CODE=$?

  if [ "$EXIT_CODE" -ne 0 ]; then
    echo "  [FAIL] $filename"
    echo ""
    # Print only the error lines from psql output, strip noise
    echo "$RESULT" | grep -iE '(error|invalid|syntax|undefined|does not exist|unrecognized)' | sed 's/^/         /'
    echo ""
    ERRORS=$((ERRORS + 1))
  else
    echo "  [PASS] $filename"
  fi

done < <(find "$PHASE_DIR" -name "*.sql" | sort)

echo ""
echo "Checked $CHECKED file(s)."
echo ""

if [ "$ERRORS" -gt 0 ]; then
  echo "=========================================="
  echo "  SQL SYNTAX VALIDATION FAILED"
  echo "  $ERRORS file(s) have errors — fix them before merging."
  echo "=========================================="
  exit 1
else
  echo "=========================================="
  echo "  ALL FILES PASSED SQL syntax validation"
  echo "=========================================="
  exit 0
fi
