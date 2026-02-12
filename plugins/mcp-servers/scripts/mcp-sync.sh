#!/bin/bash
# mcp-sync: Auto-sync MCP servers from catalog to user config
# Runs on SessionStart to:
#   1. Read servers from mcp-catalog.json
#   2. Add new servers to ~/.claude.json (mcpServers)
#   3. Preserve existing servers (never overwrite user config/credentials)

set -euo pipefail

# Paths
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${PLUGIN_ROOT}/mcp-catalog.json"
USER_CONFIG="${HOME}/.claude.json"
LOG_FILE="${HOME}/.claude/mcp-sync.log"

# Ensure catalog exists
if [[ ! -f "$CATALOG" ]]; then
    echo "[mcp-sync] Catalog not found: $CATALOG" >> "$LOG_FILE"
    exit 0
fi

# Ensure user config exists
if [[ ! -f "$USER_CONFIG" ]]; then
    echo "[mcp-sync] User config not found: $USER_CONFIG" >> "$LOG_FILE"
    exit 0
fi

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    echo "[mcp-sync] jq not found, skipping sync" >> "$LOG_FILE"
    exit 0
fi

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Main execution
main() {
    # Get server names from catalog
    local catalog_servers
    catalog_servers=$(jq -r '.mcpServers | keys[]' "$CATALOG" 2>/dev/null) || {
        log "Failed to read catalog servers"
        exit 0
    }

    # Get existing server names from user config
    local existing_servers
    existing_servers=$(jq -r '.mcpServers // {} | keys[]' "$USER_CONFIG" 2>/dev/null) || {
        log "Failed to read user config servers"
        exit 0
    }

    # Find new servers (in catalog but not in user config)
    local new_servers
    new_servers=$(comm -23 <(echo "$catalog_servers" | sort) <(echo "$existing_servers" | sort) 2>/dev/null) || true

    # Nothing to add
    if [[ -z "$new_servers" ]]; then
        return
    fi

    # Build jq filter to add only new servers
    local tmp_file
    tmp_file=$(mktemp)
    local added_count=0

    # Start with current user config
    cp "$USER_CONFIG" "$tmp_file"

    while IFS= read -r server_name; do
        [[ -z "$server_name" ]] && continue

        # Extract server config from catalog
        local server_config
        server_config=$(jq --arg name "$server_name" '.mcpServers[$name]' "$CATALOG" 2>/dev/null) || continue

        # Add to user config (ensure mcpServers key exists)
        local result_file
        result_file=$(mktemp)
        jq --arg name "$server_name" --argjson config "$server_config" '
            .mcpServers //= {} |
            .mcpServers[$name] = $config
        ' "$tmp_file" > "$result_file" && mv "$result_file" "$tmp_file"

        added_count=$((added_count + 1))
        log "Added server: $server_name"
    done <<< "$new_servers"

    # Atomic write to user config
    if [[ $added_count -gt 0 ]]; then
        mv "$tmp_file" "$USER_CONFIG"
        log "Synced $added_count new server(s) from catalog"
    else
        rm -f "$tmp_file"
    fi
}

# Run
main
