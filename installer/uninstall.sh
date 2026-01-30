#!/usr/bin/env bash
set -euo pipefail

# Claude Code Plugins — Uninstaller
# Removes user-level or project-level plugin installations

# ---------------------------------------------------------------------------
# Validate critical environment
# ---------------------------------------------------------------------------
if [ -z "${HOME:-}" ]; then
    echo "ERROR: HOME environment variable is not set." >&2
    exit 1
fi

CACHE_DIR="$HOME/.claude/plugins/cache/qazuor"
SETTINGS_FILE="$HOME/.claude/settings.json"

# ---------------------------------------------------------------------------
# Colors (auto-disable when stdout is not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

PROJECT_MODE=false
PROJECT_DIR=""

usage() {
    echo -e "${CYAN}Claude Code Plugins — Uninstaller${NC}"
    echo ""
    echo "Usage: uninstall.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --project [dir]   Uninstall from a project directory (default: current dir)"
    echo "  --help            Show this help message"
    echo ""
    echo "Without --project, removes user-level installation from ~/.claude/"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_MODE=true
            if [[ ${2:-} && ! ${2:-} == --* ]]; then
                PROJECT_DIR="$2"
                shift 2
            else
                PROJECT_DIR="$(pwd)"
                shift
            fi
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

echo -e "${CYAN}Claude Code Plugins — Uninstaller${NC}"
echo ""

if [ "$PROJECT_MODE" = true ]; then
    # --- Project-level uninstall ---
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}ERROR: Project directory does not exist: $PROJECT_DIR${NC}"
        exit 1
    fi
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    CLAUDE_DIR="$PROJECT_DIR/.claude"

    if [ ! -d "$CLAUDE_DIR" ]; then
        echo -e "${GREEN}No .claude/ directory found in $PROJECT_DIR. Nothing to do.${NC}"
        exit 0
    fi

    # Count symlinks that point into our plugins repo
    link_count=0
    for dir in agents commands skills docs templates; do
        if [ -d "$CLAUDE_DIR/$dir" ]; then
            while IFS= read -r link; do
                link_count=$((link_count + 1))
            done < <(find "$CLAUDE_DIR/$dir" -maxdepth 1 -type l 2>/dev/null)
        fi
    done

    if [ "$link_count" -eq 0 ]; then
        echo -e "${GREEN}No plugin symlinks found in $CLAUDE_DIR. Nothing to do.${NC}"
        exit 0
    fi

    echo "Found $link_count component symlinks in $CLAUDE_DIR"
    echo ""
    read -rp "Remove all plugin symlinks from this project? (y/N) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Remove symlinks from each component directory
    removed=0
    for dir in agents commands skills docs templates; do
        target="$CLAUDE_DIR/$dir"
        [ -d "$target" ] || continue
        while IFS= read -r link; do
            rm -f "$link"
            removed=$((removed + 1))
        done < <(find "$target" -maxdepth 1 -type l 2>/dev/null)
        # Remove directory if empty
        rmdir "$target" 2>/dev/null || true
    done
    echo -e "${GREEN}Removed${NC} $removed symlinks"

    # Clean settings.local.json hooks
    LOCAL_SETTINGS="$CLAUDE_DIR/settings.local.json"
    if [ -f "$LOCAL_SETTINGS" ] && command -v jq &> /dev/null; then
        if jq 'del(.hooks)' "$LOCAL_SETTINGS" > "$LOCAL_SETTINGS.tmp"; then
            # If only empty object remains, remove the file
            if [ "$(cat "$LOCAL_SETTINGS.tmp")" = "{}" ]; then
                rm -f "$LOCAL_SETTINGS" "$LOCAL_SETTINGS.tmp"
                echo -e "${GREEN}Removed${NC} $LOCAL_SETTINGS (was only hooks)"
            else
                mv "$LOCAL_SETTINGS.tmp" "$LOCAL_SETTINGS"
                echo -e "${GREEN}Cleaned${NC} hooks from $LOCAL_SETTINGS"
            fi
        else
            rm -f "$LOCAL_SETTINGS.tmp"
        fi
    fi

    # Warn about .mcp.json (don't auto-delete since user may have added their own servers)
    if [ -f "$PROJECT_DIR/.mcp.json" ]; then
        echo -e "${YELLOW}Note:${NC} $PROJECT_DIR/.mcp.json was not removed (may contain custom servers)."
        echo "  Remove it manually if no longer needed."
    fi

    # Remove .claude/ if empty
    rmdir "$CLAUDE_DIR" 2>/dev/null && echo -e "${GREEN}Removed${NC} empty $CLAUDE_DIR" || true

else
    # --- User-level uninstall ---
    if [ ! -d "$CACHE_DIR" ]; then
        echo -e "${GREEN}No plugins installed. Nothing to do.${NC}"
        exit 0
    fi

    # List installed plugins
    echo "Installed plugins:"
    for plugin_dir in "$CACHE_DIR"/*/; do
        [ -d "$plugin_dir" ] || continue
        plugin_name=$(basename "$plugin_dir")
        echo "  - $plugin_name@qazuor"
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
        if jq 'if .enabledPlugins then .enabledPlugins |= with_entries(select(.key | endswith("@qazuor") | not)) else . end' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"; then
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo -e "${GREEN}Cleaned${NC} $SETTINGS_FILE"
        else
            echo -e "${RED}Failed to clean settings.json. Manual cleanup may be needed.${NC}"
            rm -f "$SETTINGS_FILE.tmp"
        fi
    fi
fi

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
