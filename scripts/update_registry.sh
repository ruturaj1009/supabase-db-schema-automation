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

# Create registry file if it does not exist
if [ ! -f "$REGISTRY" ]; then
  echo "Registry not found — creating initial registry at $REGISTRY"
  mkdir -p "$(dirname "$REGISTRY")"
  printf '# Phase 1 Registry\n# Auto-updated by GitHub Actions.\n\nphase_1_files: []\n' > "$REGISTRY"
fi

echo "=== Updating phase_1 registry ==="
echo ""

for filepath in $(find "$PHASE_DIR" -name "*.sql" | sort); do
  filename=$(basename "$filepath")

  # Skip if already registered
  if grep -q "name: \"${filename}\"" "$REGISTRY" 2>/dev/null; then
    echo "  [skip] $filename — already registered"
    continue
  fi

  # Sequence number — guard grep -c returning exit 1 on no match
  existing=$(grep -c '^\s*- sequence:' "$REGISTRY" 2>/dev/null || true)
  existing=${existing:-0}
  seq=$((existing + 1))

  # Checksum
  checksum=$(sha256sum "$filepath" | awk '{print $1}')

  echo "  [add]  seq=$seq  $filename"

  # Replace empty placeholder on first entry
  if grep -q 'phase_1_files: \[\]' "$REGISTRY" 2>/dev/null; then
    sed -i 's/phase_1_files: \[\]/phase_1_files:/' "$REGISTRY"
  fi

  printf '\n  - sequence: %s\n    name: "%s"\n    checksum: "sha256:%s"\n    deployed_at: "%s"\n    commit_sha: "%s"\n    actor: "%s"\n    run_id: "%s"\n    status: "%s"\n' \
    "$seq" "$filename" "$checksum" "$DEPLOYED_AT" \
    "$COMMIT_SHA" "$ACTOR" "$RUN_ID" "$STATUS" \
    >> "$REGISTRY"
done

echo ""
echo "=== Registry contents ==="
cat "$REGISTRY"

exit 0
