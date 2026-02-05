#!/bin/bash
# =============================================================================
# check-updates.sh - Check for knowledge repository updates on session start
# =============================================================================
#
# Called by Claude Code on "SessionStart" hook events.
# Silently pulls the latest changes from the knowledge repository and
# notifies if there are updates available for the current project.
# =============================================================================

set -euo pipefail

KNOWLEDGE_DIR="${HOME}/.claude/knowledge-sync"
CACHE_DIR="${KNOWLEDGE_DIR}/cache"
CONFIG_FILE="${KNOWLEDGE_DIR}/config.json"
REGISTRY_FILE="${KNOWLEDGE_DIR}/registry.json"

# Exit silently if not set up
if [[ ! -d "$CACHE_DIR/.git" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    exit 0
fi

# Get the current project path
PROJECT_PATH="$(pwd)"

# Check if this project is registered
if [[ ! -f "$REGISTRY_FILE" ]]; then
    exit 0
fi

PROJECT_ENTRY=$(jq -r --arg p "$PROJECT_PATH" '.projects[$p] // empty' "$REGISTRY_FILE" 2>/dev/null)
if [[ -z "$PROJECT_ENTRY" ]]; then
    exit 0
fi

# Pull latest changes silently
cd "$CACHE_DIR"
git pull --ff-only --quiet 2>/dev/null || exit 0
NEW_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "none")

# Update lastPull in config
if command -v jq &> /dev/null && [[ -f "$CONFIG_FILE" ]]; then
    TMP_FILE=$(mktemp)
    jq --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.lastPull = $t' "$CONFIG_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CONFIG_FILE"
fi

# Compare with project's synced commit
SYNCED_COMMIT=$(echo "$PROJECT_ENTRY" | jq -r '.syncedCommit // "none"')

if [[ "$NEW_HEAD" != "$SYNCED_COMMIT" ]] && [[ "$SYNCED_COMMIT" != "none" ]]; then
    # Count changed files that affect this project
    CHANGED_COUNT=$(git diff --name-only "$SYNCED_COMMIT".."$NEW_HEAD" 2>/dev/null | wc -l || echo "0")
    if [[ "$CHANGED_COUNT" -gt 0 ]]; then
        echo "Knowledge updates available ($CHANGED_COUNT files changed). Run /knowledge-sync sync to update."
    fi
fi
