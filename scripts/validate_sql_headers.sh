#!/usr/bin/env bash
# validate_sql_headers.sh
# Checks that every .sql file in supabase/phase_1/ has the required header:
#
#   Line 1: -- file:<filename>        e.g.  -- file:admin_20260806_01.sql
#   Line 2: -- date:<YYYYMMDD>        e.g.  -- date:20260806
#
# Exits with code 1 if any file fails — blocks the PR merge.

set -euo pipefail

PHASE_DIR="supabase/phase_1"
ERRORS=0

# Regex patterns
FILE_PATTERN='^-- file:[A-Za-z0-9_.-]+\.sql$'
DATE_PATTERN='^-- date:[0-9]{8}$'

echo "=== Validating SQL headers in $PHASE_DIR ==="
echo ""

while IFS= read -r filepath; do
  filename=$(basename "$filepath")
  line1=$(sed -n '1p' "$filepath" | tr -d '\r')
  line2=$(sed -n '2p' "$filepath" | tr -d '\r')

  file_ok=true
  date_ok=true

  # ── Check line 1 ─────────────────────────────────────────────────────────
  if ! echo "$line1" | grep -qP "$FILE_PATTERN"; then
    echo "  [FAIL] $filename"
    echo "         Line 1 expected: -- file:$filename"
    echo "         Line 1 found   : $line1"
    file_ok=false
    ERRORS=$((ERRORS + 1))
  fi

  # ── Check line 1 filename matches actual filename ─────────────────────────
  if $file_ok; then
    declared_name="${line1#-- file:}"
    if [ "$declared_name" != "$filename" ]; then
      echo "  [FAIL] $filename"
      echo "         Line 1 filename mismatch"
      echo "         Expected : -- file:$filename"
      echo "         Found    : $line1"
      ERRORS=$((ERRORS + 1))
      file_ok=false
    fi
  fi

  # ── Check line 2 ─────────────────────────────────────────────────────────
  if ! echo "$line2" | grep -qP "$DATE_PATTERN"; then
    echo "  [FAIL] $filename"
    echo "         Line 2 expected: -- date:YYYYMMDD  (e.g. -- date:20260806)"
    echo "         Line 2 found   : $line2"
    date_ok=false
    ERRORS=$((ERRORS + 1))
  fi

  # ── Check date in line 2 is a valid calendar date ─────────────────────────
  if $date_ok; then
    declared_date="${line2#-- date:}"
    if ! date -d "${declared_date:0:4}-${declared_date:4:2}-${declared_date:6:2}" &>/dev/null; then
      echo "  [FAIL] $filename"
      echo "         Line 2 date '$declared_date' is not a valid calendar date"
      ERRORS=$((ERRORS + 1))
      date_ok=false
    fi
  fi

  if $file_ok && $date_ok; then
    echo "  [PASS] $filename"
  fi

done < <(find "$PHASE_DIR" -name "*.sql" | sort)

echo ""

if [ "$ERRORS" -gt 0 ]; then
  echo "=========================================="
  echo "  VALIDATION FAILED — $ERRORS error(s) found"
  echo "  Every .sql file must start with:"
  echo ""
  echo "    -- file:<filename>.sql"
  echo "    -- date:<YYYYMMDD>"
  echo ""
  echo "  Example:"
  echo "    -- file:admin_20260806_01.sql"
  echo "    -- date:20260806"
  echo "=========================================="
  exit 1
else
  echo "=========================================="
  echo "  ALL FILES PASSED header validation"
  echo "=========================================="
  exit 0
fi
