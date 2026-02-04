#!/bin/bash
# permissions-sync: Manual sync command
# Usage: sync-all.sh [--all] [--dry-run]

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_PERMS="${PLUGIN_ROOT}/templates/base-permissions.json"
PROJECTS_ROOT="${HOME}/projects"
DRY_RUN=false
SYNC_ALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            SYNC_ALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Count new permissions of a given type
count_new_perms() {
    local settings_file="$1"
    local perm_type="$2"

    jq -r ".permissions.${perm_type} // [] | .[]" "$settings_file" 2>/dev/null | while read perm; do
        if [[ -n "$perm" ]] && ! jq -e --arg p "$perm" ".permissions.${perm_type} | index(\$p)" "$BASE_PERMS" >/dev/null 2>&1; then
            echo "$perm"
        fi
    done | wc -l
}

# Add new permissions of a given type
add_new_perms() {
    local settings_file="$1"
    local perm_type="$2"

    jq -r ".permissions.${perm_type} // [] | .[]" "$settings_file" 2>/dev/null | while read perm; do
        if [[ -n "$perm" ]] && ! jq -e --arg p "$perm" ".permissions.${perm_type} | index(\$p)" "$BASE_PERMS" >/dev/null 2>&1; then
            local tmp_file
            tmp_file=$(mktemp)
            jq --arg p "$perm" ".permissions.${perm_type} += [\$p] | .permissions.${perm_type} |= unique | .permissions.${perm_type} |= sort" "$BASE_PERMS" > "$tmp_file" && mv "$tmp_file" "$BASE_PERMS"
            echo "    + ${perm_type}: $perm"
        fi
    done
}

# Sync a single project
sync_project() {
    local project_path="$1"
    local settings_file="${project_path}/.claude/settings.local.json"

    if [[ ! -f "$settings_file" ]]; then
        return
    fi

    local project_name
    project_name=$(basename "$project_path")

    # Count new permissions for each type
    local new_allows new_asks new_denies
    new_allows=$(count_new_perms "$settings_file" "allow")
    new_asks=$(count_new_perms "$settings_file" "ask")
    new_denies=$(count_new_perms "$settings_file" "deny")

    if [[ $new_allows -gt 0 ]] || [[ $new_asks -gt 0 ]] || [[ $new_denies -gt 0 ]]; then
        log_info "$project_name: $new_allows new allows, $new_asks new asks, $new_denies new denies"

        if [[ "$DRY_RUN" == "false" ]]; then
            add_new_perms "$settings_file" "allow"
            add_new_perms "$settings_file" "ask"
            add_new_perms "$settings_file" "deny"
        fi
    fi

    # Merge base to project (unless dry-run)
    if [[ "$DRY_RUN" == "false" ]]; then
        local tmp_file
        tmp_file=$(mktemp)
        local base_allow base_ask base_deny
        base_allow=$(jq -c '.permissions.allow // []' "$BASE_PERMS")
        base_ask=$(jq -c '.permissions.ask // []' "$BASE_PERMS")
        base_deny=$(jq -c '.permissions.deny // []' "$BASE_PERMS")

        jq --argjson allow "$base_allow" --argjson ask "$base_ask" --argjson deny "$base_deny" '
            .permissions.allow = ($allow + (.permissions.allow // []) | unique | sort) |
            .permissions.ask = ($ask + (.permissions.ask // []) | unique | sort) |
            .permissions.deny = ($deny + (.permissions.deny // []) | unique | sort)
        ' "$settings_file" > "$tmp_file" && mv "$tmp_file" "$settings_file"
    fi
}

# Main
main() {
    if [[ ! -f "$BASE_PERMS" ]]; then
        log_warn "Base permissions file not found: $BASE_PERMS"
        exit 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - no changes will be made"
        echo ""
    fi

    if [[ "$SYNC_ALL" == "true" ]]; then
        log_info "Scanning all projects in $PROJECTS_ROOT..."
        echo ""

        # Find all projects with .claude directory
        find "$PROJECTS_ROOT" -maxdepth 4 -type d -name ".claude" ! -path "*/node_modules/*" 2>/dev/null | while read claude_dir; do
            project_path=$(dirname "$claude_dir")
            sync_project "$project_path"
        done
    else
        # Sync current project only
        if [[ -f ".claude/settings.local.json" ]]; then
            log_info "Syncing current project: $(pwd)"
            sync_project "$(pwd)"
        else
            log_warn "No .claude/settings.local.json found in current directory"
            exit 1
        fi
    fi

    echo ""
    log_success "Sync complete!"

    # Show summary
    local total_allow total_ask total_deny
    total_allow=$(jq '.permissions.allow | length' "$BASE_PERMS")
    total_ask=$(jq '.permissions.ask | length' "$BASE_PERMS")
    total_deny=$(jq '.permissions.deny | length' "$BASE_PERMS")
    log_info "Base now has: $total_allow allows, $total_ask asks, $total_deny denies"
}

main
