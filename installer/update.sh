#!/usr/bin/env bash
set -euo pipefail

# Claude Code Plugins — Updater
# Since we use symlinks, just pull the latest and verify.

# ---------------------------------------------------------------------------
# Validate critical environment
# ---------------------------------------------------------------------------
if [ -z "${HOME:-}" ]; then
    echo "ERROR: HOME environment variable is not set." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$HOME/.claude/plugins/cache/qazuor"

# ---------------------------------------------------------------------------
# Colors (auto-disable when stdout is not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN='' CYAN='' YELLOW='' RED='' NC=''
fi

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required but not installed.${NC}"
    echo "Install it with: sudo apt install jq (Linux) or brew install jq (macOS)"
    exit 1
fi

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

if [ ! -d "$CACHE_DIR" ]; then
    echo -e "${YELLOW}No plugins installed in $CACHE_DIR. Run install.sh first.${NC}"
    exit 0
fi

for plugin_dir in "$CACHE_DIR"/*/; do
    [ -d "$plugin_dir" ] || continue
    for version_dir in "$plugin_dir"/*/; do
        if [ -L "$version_dir" ]; then
            # Use readlink without -f to avoid following chains unsafely
            target=$(readlink "$version_dir" 2>/dev/null) || {
                echo -e "  ${YELLOW}!${NC} $(basename "$plugin_dir")@qazuor — unreadable symlink"
                BROKEN=$((BROKEN + 1))
                continue
            }
            if [ -d "$target" ]; then
                echo -e "  ${GREEN}✓${NC} $(basename "$plugin_dir")@qazuor"
            else
                echo -e "  ${YELLOW}!${NC} $(basename "$plugin_dir")@qazuor — broken symlink"
                BROKEN=$((BROKEN + 1))
            fi
        fi
    done
done

if [ $BROKEN -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}$BROKEN broken symlinks found. Run install.sh to fix.${NC}"
else
    echo ""
    echo -e "${GREEN}All plugins up to date.${NC}"
fi
