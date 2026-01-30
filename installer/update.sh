#!/usr/bin/env bash
set -euo pipefail

# Claude Code Plugins — Updater
# Since we use symlinks, just pull the latest and verify.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$HOME/.claude/plugins/cache/qazuor"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}Claude Code Plugins — Updater${NC}"
echo ""

# Pull latest
cd "$REPO_DIR"
echo "Pulling latest changes..."
git pull --ff-only 2>/dev/null || {
    echo -e "${YELLOW}Could not fast-forward. Please resolve manually.${NC}"
    exit 1
}

# Verify symlinks are intact
echo ""
echo "Verifying installations..."
BROKEN=0
for plugin_dir in "$CACHE_DIR"/*/; do
    if [ -d "$plugin_dir" ]; then
        for version_dir in "$plugin_dir"/*/; do
            if [ -L "$version_dir" ]; then
                target=$(readlink -f "$version_dir" 2>/dev/null || readlink "$version_dir")
                if [ -d "$target" ]; then
                    echo -e "  ${GREEN}✓${NC} $(basename "$plugin_dir")@qazuor"
                else
                    echo -e "  ${YELLOW}⚠${NC} $(basename "$plugin_dir")@qazuor — broken symlink"
                    BROKEN=$((BROKEN + 1))
                fi
            fi
        done
    fi
done

if [ $BROKEN -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}$BROKEN broken symlinks found. Run install.sh to fix.${NC}"
else
    echo ""
    echo -e "${GREEN}All plugins up to date.${NC}"
fi
