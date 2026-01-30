#!/usr/bin/env bash
set -euo pipefail

# Claude Code Plugins — Installer
# Creates symlinks from this repo to ~/.claude/plugins/cache/qazuor/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGINS_DIR="$REPO_DIR/plugins"
CACHE_DIR="$HOME/.claude/plugins/cache/qazuor"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Defaults
PROFILE=""
ENABLE_PLUGINS=()
SETUP_MCP=false

usage() {
    echo -e "${CYAN}Claude Code Plugins Installer${NC}"
    echo ""
    echo "Usage: install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --profile <name>     Install a preset profile (full-stack, minimal, backend-only, frontend-only)"
    echo "  --enable <plugin>    Enable a specific plugin (can be repeated)"
    echo "  --setup-mcp          Run interactive MCP API key setup after installation"
    echo "  --list               List available plugins and profiles"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  install.sh --profile full-stack"
    echo "  install.sh --profile minimal --setup-mcp"
    echo "  install.sh --enable core --enable notifications"
}

list_available() {
    echo -e "${CYAN}Available Plugins:${NC}"
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        if [ -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
            local name desc version
            name=$(jq -r '.name' "$plugin_dir/.claude-plugin/plugin.json")
            desc=$(jq -r '.description' "$plugin_dir/.claude-plugin/plugin.json")
            version=$(jq -r '.version' "$plugin_dir/.claude-plugin/plugin.json")
            echo -e "  ${GREEN}$name${NC} v$version — $desc"
        fi
    done
    echo ""
    echo -e "${CYAN}Available Profiles:${NC}"
    for profile_file in "$SCRIPT_DIR/profiles"/*.json; do
        local pname pdesc pplugins
        pname=$(jq -r '.name' "$profile_file")
        pdesc=$(jq -r '.description' "$profile_file")
        pplugins=$(jq -r '.plugins | join(", ")' "$profile_file")
        echo -e "  ${GREEN}$pname${NC} — $pdesc"
        echo -e "    Plugins: $pplugins"
    done
}

install_plugin() {
    local plugin_dir="$1"
    local plugin_name version target_dir

    if [ ! -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
        echo -e "${RED}ERROR: No plugin.json found in $plugin_dir${NC}"
        return 1
    fi

    plugin_name=$(jq -r '.name' "$plugin_dir/.claude-plugin/plugin.json")
    version=$(jq -r '.version' "$plugin_dir/.claude-plugin/plugin.json")
    target_dir="$CACHE_DIR/$plugin_name/$version"

    # Create parent directory
    mkdir -p "$CACHE_DIR/$plugin_name"

    # Remove existing symlink or directory
    if [ -L "$target_dir" ] || [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi

    # Create symlink
    ln -sfn "$plugin_dir" "$target_dir"
    echo -e "  ${GREEN}✓${NC} $plugin_name@qazuor v$version → $target_dir"
}

update_settings() {
    local plugins_to_enable=("$@")

    # Ensure settings file exists
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo '{}' > "$SETTINGS_FILE"
    fi

    # Build enabledPlugins object
    local enabled_json="{}"
    for plugin_name in "${plugins_to_enable[@]}"; do
        enabled_json=$(echo "$enabled_json" | jq --arg key "${plugin_name}@qazuor" '. + {($key): true}')
    done

    # Merge into settings.json
    local current
    current=$(cat "$SETTINGS_FILE")
    echo "$current" | jq --argjson plugins "$enabled_json" '.enabledPlugins = ((.enabledPlugins // {}) + $plugins)' > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

    echo -e "${GREEN}Updated${NC} $SETTINGS_FILE with enabled plugins"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --enable)
            ENABLE_PLUGINS+=("$2")
            shift 2
            ;;
        --setup-mcp)
            SETUP_MCP=true
            shift
            ;;
        --list)
            list_available
            exit 0
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

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required but not installed.${NC}"
    echo "Install it with: sudo apt install jq (Linux) or brew install jq (macOS)"
    exit 1
fi

echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Claude Code Plugins — Installer    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# Determine which plugins to install
PLUGINS_TO_INSTALL=()

if [ -n "$PROFILE" ]; then
    local_profile="$SCRIPT_DIR/profiles/$PROFILE.json"
    if [ ! -f "$local_profile" ]; then
        echo -e "${RED}ERROR: Profile '$PROFILE' not found.${NC}"
        echo "Available profiles: full-stack, minimal, backend-only, frontend-only"
        exit 1
    fi
    echo -e "${BLUE}Profile:${NC} $PROFILE"
    mapfile -t PLUGINS_TO_INSTALL < <(jq -r '.plugins[]' "$local_profile")
elif [ ${#ENABLE_PLUGINS[@]} -gt 0 ]; then
    PLUGINS_TO_INSTALL=("${ENABLE_PLUGINS[@]}")
else
    # Default: install all plugins
    echo -e "${YELLOW}No profile or plugins specified. Installing all plugins.${NC}"
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        if [ -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
            PLUGINS_TO_INSTALL+=($(jq -r '.name' "$plugin_dir/.claude-plugin/plugin.json"))
        fi
    done
fi

echo -e "${BLUE}Plugins:${NC} ${PLUGINS_TO_INSTALL[*]}"
echo ""

# Install plugins
echo -e "${CYAN}Installing plugins...${NC}"
INSTALLED=()
for plugin_name in "${PLUGINS_TO_INSTALL[@]}"; do
    plugin_dir="$PLUGINS_DIR/$plugin_name"
    if [ -d "$plugin_dir" ]; then
        install_plugin "$plugin_dir"
        INSTALLED+=("$plugin_name")
    else
        echo -e "  ${YELLOW}⚠${NC} Plugin '$plugin_name' not found in $PLUGINS_DIR"
    fi
done
echo ""

# Update settings.json
if [ ${#INSTALLED[@]} -gt 0 ]; then
    echo -e "${CYAN}Updating settings...${NC}"
    update_settings "${INSTALLED[@]}"
    echo ""
fi

# MCP API key setup
if [ "$SETUP_MCP" = true ] && [[ " ${INSTALLED[*]} " =~ " mcp-servers " ]]; then
    echo -e "${CYAN}MCP Server API Key Setup${NC}"
    echo "Some MCP servers require API keys. Enter them below (press Enter to skip)."
    echo ""

    declare -A MCP_KEYS=(
        ["PERPLEXITY_API_KEY"]="Perplexity AI (web search)"
        ["GITHUB_TOKEN"]="GitHub (issues, PRs, repos)"
        ["VERCEL_TOKEN"]="Vercel (deployment)"
        ["LINEAR_API_KEY"]="Linear (issue tracking)"
        ["NEON_API_KEY"]="Neon (PostgreSQL cloud)"
        ["SENTRY_AUTH_TOKEN"]="Sentry (error monitoring)"
        ["BRAVE_API_KEY"]="Brave Search"
        ["NOTION_TOKEN"]="Notion (integration)"
        ["SLACK_BOT_TOKEN"]="Slack (messaging)"
        ["FIGMA_TOKEN"]="Figma (design)"
        ["MERCADOPAGO_ACCESS_TOKEN"]="MercadoPago (payments)"
        ["SUPABASE_ACCESS_TOKEN"]="Supabase (BaaS)"
    )

    ENV_FILE="$HOME/.claude/.env.mcp"
    touch "$ENV_FILE"

    for key in "${!MCP_KEYS[@]}"; do
        desc="${MCP_KEYS[$key]}"
        current=""
        if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
            current=$(grep "^${key}=" "$ENV_FILE" | cut -d'=' -f2-)
            echo -ne "  ${desc} [${GREEN}configured${NC}] (Enter to keep, or new value): "
        else
            echo -ne "  ${desc}: "
        fi
        read -r value
        if [ -n "$value" ]; then
            # Remove existing and add new
            grep -v "^${key}=" "$ENV_FILE" > "$ENV_FILE.tmp" 2>/dev/null || true
            echo "${key}=${value}" >> "$ENV_FILE.tmp"
            mv "$ENV_FILE.tmp" "$ENV_FILE"
            echo -e "    ${GREEN}✓${NC} Saved"
        fi
    done
    chmod 600 "$ENV_FILE"
    echo ""
    echo -e "${GREEN}API keys saved to${NC} $ENV_FILE"
    echo ""
fi

# Summary
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Installation Complete!         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "Installed ${GREEN}${#INSTALLED[@]}${NC} plugins to $CACHE_DIR"
echo ""
echo "Next steps:"
echo "  1. Open Claude Code in any project"
echo "  2. Try /help to see available commands"
echo "  3. Try /quality-check to validate your code"
echo ""
echo "To update: cd $(basename "$REPO_DIR") && git pull"
echo "  (symlinks mean updates are instant)"
