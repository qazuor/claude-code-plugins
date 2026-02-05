#!/bin/bash
# =============================================================================
# sync.sh - Sync updated knowledge components to the current project
# =============================================================================
#
# Copies updated files from the knowledge cache to the project's .claude/
# directory based on the registry.
# =============================================================================

set -euo pipefail

KNOWLEDGE_DIR="${HOME}/.claude/knowledge-sync"
CACHE_DIR="${KNOWLEDGE_DIR}/cache"
REGISTRY_FILE="${KNOWLEDGE_DIR}/registry.json"
PROJECT_PATH="${1:-$(pwd)}"

# Validate setup
if [[ ! -d "$CACHE_DIR" ]] || [[ ! -f "$REGISTRY_FILE" ]]; then
    echo "ERROR: knowledge-sync not set up. Run /knowledge-sync setup first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required. Install it with: sudo apt install jq"
    exit 1
fi

# Get project entry
PROJECT_ENTRY=$(jq -r --arg p "$PROJECT_PATH" '.projects[$p] // empty' "$REGISTRY_FILE" 2>/dev/null)
if [[ -z "$PROJECT_ENTRY" ]]; then
    echo "ERROR: Project not registered. Run /knowledge-sync install --detect first."
    exit 1
fi

# Pull latest
cd "$CACHE_DIR"
git pull --ff-only --quiet 2>/dev/null || true
NEW_HEAD=$(git rev-parse HEAD)

# Sync each component type
UPDATED=0

sync_components() {
    local comp_type="$1"
    local src_dir="$2"
    local dest_dir="$3"
    local is_skill="$4"

    local components
    components=$(echo "$PROJECT_ENTRY" | jq -r ".${comp_type} // [] | .[]" 2>/dev/null)

    for comp in $components; do
        [[ -z "$comp" ]] && continue

        if [[ "$is_skill" == "true" ]]; then
            local src="${CACHE_DIR}/${src_dir}/${comp}/SKILL.md"
            local dest="${PROJECT_PATH}/.claude/${dest_dir}/${comp}/SKILL.md"
            mkdir -p "${PROJECT_PATH}/.claude/${dest_dir}/${comp}"
        else
            local src="${CACHE_DIR}/${src_dir}/${comp}.md"
            local dest="${PROJECT_PATH}/.claude/${dest_dir}/${comp}.md"
            mkdir -p "${PROJECT_PATH}/.claude/${dest_dir}"
        fi

        if [[ -f "$src" ]]; then
            if ! diff -q "$src" "$dest" &>/dev/null; then
                cp "$src" "$dest"
                echo "  Updated: ${dest_dir}/${comp}"
                UPDATED=$((UPDATED + 1))
            fi
        fi
    done
}

echo "Syncing knowledge components..."
echo ""

sync_components "agents" "agents" "agents" "false"
sync_components "skills" "skills" "skills" "true"
sync_components "commands" "commands" "commands" "false"
sync_components "docs" "docs" "docs" "false"
sync_components "templates" "templates" "templates" "false"

# Update registry
TMP_FILE=$(mktemp)
jq --arg p "$PROJECT_PATH" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg c "$NEW_HEAD" \
    '.projects[$p].syncedAt = $t | .projects[$p].syncedCommit = $c' \
    "$REGISTRY_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$REGISTRY_FILE"

echo ""
if [[ $UPDATED -gt 0 ]]; then
    echo "Synced $UPDATED component(s)."
else
    echo "All components are up to date."
fi
