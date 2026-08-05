#!/usr/bin/env bash
# update_registry.sh
# Scans supabase/phase_1/*.sql and appends new entries to phase_1_registry.yml
#
# Usage:
#   ./scripts/update_registry.sh <commit_sha> <actor> <run_id> <status>

REGISTRY="supabase/phase_1_registry.yml"
PHASE_DIR="supabase/phase_1"
COMMIT_SHA="${1:-unknown}"
ACTOR="${2:-unknown}"
RUN_ID="${3:-unknown}"
STATUS="${4:-applied}"
DEPLOYED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
ERRORS=0

echo "=== Updating phase_1 registry ==="
echo ""

for filepath in $(find "$PHASE_DIR" -name "*.sql" | sort); do
  filename=$(basename "$filepath")

  # Check if this filename is already in the registry
  already_registered=0
  if grep -q "name: \"${filename}\"" "$REGISTRY" 2>/dev/null; then
    already_registered=1
  fi

  if [ "$already_registered" -eq 1 ]; then
    echo "  [skip] $filename — already in registry"
    continue
  fi

  # Count current entries for sequence number
  seq=1
  existing=$(grep -c '^\s*- sequence:' "$REGISTRY" 2>/dev/null) || existing=0
  seq=$((existing + 1))

  # Compute checksum
  checksum=$(sha256sum "$filepath" | awk '{print $1}')
  if [ -z "$checksum" ]; then
    echo "  [ERROR] Could not compute checksum for $filename"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  echo "  [add]  sequence=$seq  $filename  sha256:${checksum:0:12}..."

  # On first entry replace the empty placeholder
  if grep -q 'phase_1_files: \[\]' "$REGISTRY" 2>/dev/null; then
    sed -i 's/phase_1_files: \[\]/phase_1_files:/' "$REGISTRY"
  fi

  # Append entry — use printf to avoid heredoc CRLF issues on some runners
  printf '\n  - sequence: %s\n    name: "%s"\n    checksum: "sha256:%s"\n    deployed_at: "%s"\n    commit_sha: "%s"\n    actor: "%s"\n    run_id: "%s"\n    status: "%s"\n' \
    "$seq" "$filename" "$checksum" "$DEPLOYED_AT" \
    "$COMMIT_SHA" "$ACTOR" "$RUN_ID" "$STATUS" \
    >> "$REGISTRY"

done

echo ""
echo "Registry updated: $REGISTRY"
echo ""
echo "Current stack:"
grep -E '(sequence:|name:|status:)' "$REGISTRY" | sed 's/^/  /' || true

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "ERROR: $ERRORS file(s) failed to register."
  exit 1
fi

exit 0
