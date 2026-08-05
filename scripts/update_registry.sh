#!/usr/bin/env bash
# update_registry.sh
# Scans supabase/phase_1/*.sql and appends any new entries to phase_1_registry.yml
# Called by GitHub Actions after a successful db push.
#
# Usage:
#   ./scripts/update_registry.sh <commit_sha> <actor> <run_id> <status>

set -uo pipefail
# Note: -e is intentionally omitted so grep non-matches don't abort the script

REGISTRY="supabase/phase_1_registry.yml"
PHASE_DIR="supabase/phase_1"
COMMIT_SHA="${1:-unknown}"
ACTOR="${2:-unknown}"
RUN_ID="${3:-unknown}"
STATUS="${4:-applied}"
DEPLOYED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Return list of already-registered filenames from the registry
registered_names() {
  grep '^\s*name:' "$REGISTRY" | awk '{print $2}' | tr -d '"'
}

# Count existing entries to determine next sequence number
next_sequence() {
  local count
  count=$(grep -c '^\s*- sequence:' "$REGISTRY" || true)
  echo $((count + 1))
}

echo "=== Updating phase_1 registry ==="
echo ""

# Sort SQL files by name
while IFS= read -r filepath; do
  filename=$(basename "$filepath")

  # Skip if already registered (match on full filename, not version prefix)
  if registered_names | grep -qx "\"${filename}\"" || registered_names | grep -qx "${filename}"; then
    echo "  [skip] $filename — already in registry"
    continue
  fi

  checksum=$(sha256sum "$filepath" | awk '{print $1}')
  seq=$(next_sequence)

  echo "  [add]  sequence=$seq  $filename"

  # Replace empty placeholder on first entry
  if grep -q 'phase_1_files: \[\]' "$REGISTRY"; then
    sed -i 's/phase_1_files: \[\]/phase_1_files:/' "$REGISTRY"
  fi

  # Append the new entry
  cat >> "$REGISTRY" <<EOF

  - sequence: ${seq}
    name: "${filename}"
    checksum: "sha256:${checksum}"
    deployed_at: "${DEPLOYED_AT}"
    commit_sha: "${COMMIT_SHA}"
    actor: "${ACTOR}"
    run_id: "${RUN_ID}"
    status: "${STATUS}"
EOF

done < <(find "$PHASE_DIR" -name "*.sql" | sort)

echo ""
echo "Registry updated: $REGISTRY"
echo ""
echo "Current stack:"
grep -E '^\s+(sequence|name|status):' "$REGISTRY" | sed 's/^/  /'
