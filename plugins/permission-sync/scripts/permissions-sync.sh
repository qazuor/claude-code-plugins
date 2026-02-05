#!/bin/bash
# permissions-sync: Auto-learn and sync permissions across projects
# Runs on SessionStart to:
#   1. Detect new permissions in project that aren't in base
#   2. Add them to base-permissions.json (auto-learn)
#   3. Merge base permissions into project settings

set -euo pipefail

# Paths
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_PERMS="${PLUGIN_ROOT}/templates/base-permissions.json"
PROJECT_SETTINGS=".claude/settings.local.json"
LOG_FILE="${HOME}/.claude/permissions-sync.log"

# Ensure base permissions file exists
if [[ ! -f "$BASE_PERMS" ]]; then
    echo "[permissions-sync] Base permissions file not found: $BASE_PERMS" >> "$LOG_FILE"
    exit 0
fi

# Check if we're in a project with Claude settings
if [[ ! -f "$PROJECT_SETTINGS" ]]; then
    # No project settings, nothing to sync
    exit 0
fi

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    echo "[permissions-sync] jq not found, skipping sync" >> "$LOG_FILE"
    exit 0
fi

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Extract permissions from project that aren't in base for a given type
extract_new_perms() {
    local perm_type="$1"  # "allow", "ask", or "deny"
    local base_perms project_perms

    base_perms=$(jq -r ".permissions.${perm_type} // [] | .[]" "$BASE_PERMS" 2>/dev/null | sort -u)
    project_perms=$(jq -r ".permissions.${perm_type} // [] | .[]" "$PROJECT_SETTINGS" 2>/dev/null | sort -u)

    # Find permissions in project but not in base
    comm -23 <(echo "$project_perms") <(echo "$base_perms") 2>/dev/null || true
}

# Add permission to base file
add_to_base() {
    local perm_type="$1"  # "allow", "ask", or "deny"
    local perm="$2"

    # Skip empty permissions
    [[ -z "$perm" ]] && return

    # Add to base using jq
    local tmp_file
    tmp_file=$(mktemp)

    jq --arg p "$perm" ".permissions.${perm_type} += [\$p] | .permissions.${perm_type} |= unique | .permissions.${perm_type} |= sort" \
        "$BASE_PERMS" > "$tmp_file" && mv "$tmp_file" "$BASE_PERMS"

    log "Added to base ${perm_type}: $perm"
}

# Merge base permissions into project (preserving project hooks and other settings)
merge_to_project() {
    local tmp_file
    tmp_file=$(mktemp)

    # Get base permissions
    local base_allow base_ask base_deny
    base_allow=$(jq -c '.permissions.allow // []' "$BASE_PERMS")
    base_ask=$(jq -c '.permissions.ask // []' "$BASE_PERMS")
    base_deny=$(jq -c '.permissions.deny // []' "$BASE_PERMS")

    # Merge into project, keeping other project settings (hooks, etc.)
    jq --argjson allow "$base_allow" --argjson ask "$base_ask" --argjson deny "$base_deny" '
        .permissions.allow = ($allow + (.permissions.allow // []) | unique | sort) |
        .permissions.ask = ($ask + (.permissions.ask // []) | unique | sort) |
        .permissions.deny = ($deny + (.permissions.deny // []) | unique | sort)
    ' "$PROJECT_SETTINGS" > "$tmp_file" && mv "$tmp_file" "$PROJECT_SETTINGS"
}

# Main execution
main() {
    local new_allows new_asks new_denies
    local added_count=0

    # Extract new permissions for each type
    new_allows=$(extract_new_perms "allow")
    new_asks=$(extract_new_perms "ask")
    new_denies=$(extract_new_perms "deny")

    # Add new allows to base
    if [[ -n "$new_allows" ]]; then
        while IFS= read -r perm; do
            if [[ -n "$perm" ]]; then
                add_to_base "allow" "$perm"
                added_count=$((added_count + 1))
            fi
        done <<< "$new_allows"
    fi

    # Add new asks to base
    if [[ -n "$new_asks" ]]; then
        while IFS= read -r perm; do
            if [[ -n "$perm" ]]; then
                add_to_base "ask" "$perm"
                added_count=$((added_count + 1))
            fi
        done <<< "$new_asks"
    fi

    # Add new denies to base
    if [[ -n "$new_denies" ]]; then
        while IFS= read -r perm; do
            if [[ -n "$perm" ]]; then
                add_to_base "deny" "$perm"
                added_count=$((added_count + 1))
            fi
        done <<< "$new_denies"
    fi

    # Merge base into project
    merge_to_project

    # Log summary
    if [[ $added_count -gt 0 ]]; then
        log "Synced $added_count new permission(s) from $(pwd)"
    fi
}

# Run
main
