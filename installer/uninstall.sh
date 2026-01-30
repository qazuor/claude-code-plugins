#!/usr/bin/env bash
set -euo pipefail

# Claude Code Plugins — Uninstaller

CACHE_DIR="$HOME/.claude/plugins/cache/qazuor"
SETTINGS_FILE="$HOME/.claude/settings.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Claude Code Plugins — Uninstaller${NC}"
echo ""

if [ ! -d "$CACHE_DIR" ]; then
    echo -e "${GREEN}No plugins installed. Nothing to do.${NC}"
    exit 0
fi

# List installed plugins
echo "Installed plugins:"
for plugin_dir in "$CACHE_DIR"/*/; do
    if [ -d "$plugin_dir" ]; then
        plugin_name=$(basename "$plugin_dir")
        echo "  - $plugin_name@qazuor"
    fi
done
echo ""

read -rp "Remove all qazuor plugins? (y/N) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Remove symlinks
rm -rf "$CACHE_DIR"
echo -e "${GREEN}Removed${NC} $CACHE_DIR"

# Clean settings.json
if [ -f "$SETTINGS_FILE" ] && command -v jq &> /dev/null; then
    # Remove all @qazuor entries from enabledPlugins
    jq 'if .enabledPlugins then .enabledPlugins |= with_entries(select(.key | endswith("@qazuor") | not)) else . end' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    echo -e "${GREEN}Cleaned${NC} $SETTINGS_FILE"
fi

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
