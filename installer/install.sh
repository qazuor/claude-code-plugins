#!/usr/bin/env bash
set -euo pipefail

# Claude Code Plugins — Installer
# User-level:    Creates symlinks to ~/.claude/plugins/cache/qazuor/
# Project-level: Symlinks individual components into .claude/ of the current project

# ---------------------------------------------------------------------------
# Validate critical environment
# ---------------------------------------------------------------------------
if [ -z "${HOME:-}" ]; then
    echo "ERROR: HOME environment variable is not set." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGINS_DIR="$REPO_DIR/plugins"
CACHE_DIR="$HOME/.claude/plugins/cache/qazuor"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Cleanup temp files on interrupt/error
_CLEANUP_FILES=()
cleanup() {
    for f in "${_CLEANUP_FILES[@]}"; do
        rm -f "$f" 2>/dev/null
    done
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Colors (auto-disable when stdout is not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

# Defaults
PROFILE=""
ENABLE_PLUGINS=()
SETUP_MCP=false
PROJECT_MODE=false
PROJECT_DIR=""
DRY_RUN=false
SKIP_EXTRAS=false

usage() {
    echo -e "${CYAN}Claude Code Plugins Installer${NC}"
    echo ""
    echo "Usage: install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --profile <name>     Install a preset profile (full-stack, minimal, backend-only, frontend-only)"
    echo "  --enable <plugin>    Enable a specific plugin (can be repeated)"
    echo "  --project [dir]      Install into a project directory instead of user-level (~/.claude)"
    echo "                       Uses current directory if no dir specified"
    echo "  --setup-mcp          Run interactive MCP API key setup after installation"
    echo "  --skip-extras        Skip recommended third-party plugins prompt"
    echo "  --dry-run            Show what would be installed without making changes"
    echo "  --list               List available plugins and profiles"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  install.sh --profile full-stack                    # User-level (all projects)"
    echo "  install.sh --profile full-stack --project          # Project-level (current dir)"
    echo "  install.sh --profile minimal --project /path/to/project"
    echo "  install.sh --enable core --enable notifications"
}

list_available() {
    echo -e "${CYAN}Available Plugins:${NC}"
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        [ -d "$plugin_dir" ] || continue
        if [ -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
            local name desc version
            name=$(jq -r '.name // "unknown"' "$plugin_dir/.claude-plugin/plugin.json") || {
                echo -e "  ${RED}✗${NC} Failed to read $(basename "$plugin_dir") manifest"
                continue
            }
            desc=$(jq -r '.description // ""' "$plugin_dir/.claude-plugin/plugin.json") || true
            version=$(jq -r '.version // "?"' "$plugin_dir/.claude-plugin/plugin.json") || true
            echo -e "  ${GREEN}$name${NC} v$version — $desc"
        fi
    done
    echo ""
    echo -e "${CYAN}Available Profiles:${NC}"
    for profile_file in "$SCRIPT_DIR/profiles"/*.json; do
        [ -f "$profile_file" ] || continue
        local pname pdesc pplugins
        pname=$(jq -r '.name // "unknown"' "$profile_file") || {
            echo -e "  ${RED}✗${NC} Failed to read $(basename "$profile_file")"
            continue
        }
        pdesc=$(jq -r '.description // ""' "$profile_file") || true
        pplugins=$(jq -r '.plugins | join(", ")' "$profile_file") || true
        echo -e "  ${GREEN}$pname${NC} — $pdesc"
        echo -e "    Plugins: $pplugins"
    done
}

# ---------------------------------------------------------------------------
# User-level installation functions
# ---------------------------------------------------------------------------

install_plugin() {
    local plugin_dir="$1"
    local plugin_name version target_dir

    if [ ! -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
        echo -e "  ${RED}✗${NC} No plugin.json found in $plugin_dir"
        return 1
    fi

    plugin_name=$(jq -r '.name // empty' "$plugin_dir/.claude-plugin/plugin.json") || {
        echo -e "  ${RED}✗${NC} Failed to parse plugin.json in $plugin_dir"
        return 1
    }
    if [ -z "$plugin_name" ]; then
        echo -e "  ${RED}✗${NC} Missing 'name' field in $plugin_dir/.claude-plugin/plugin.json"
        return 1
    fi

    version=$(jq -r '.version // "0.0.0"' "$plugin_dir/.claude-plugin/plugin.json") || true
    if [ -z "$version" ]; then
        echo -e "  ${YELLOW}!${NC} Could not read version from $plugin_dir, using 0.0.0"
        version="0.0.0"
    fi
    target_dir="$CACHE_DIR/$plugin_name/$version"

    # Create parent directory safely (verify it's not a symlink to elsewhere)
    local parent_dir="$CACHE_DIR/$plugin_name"
    if [ -L "$parent_dir" ]; then
        echo -e "  ${YELLOW}!${NC} Removing unexpected symlink at $parent_dir"
        rm -f "$parent_dir"
    fi
    mkdir -p "$parent_dir"

    # Remove existing symlink or directory
    if [ -L "$target_dir" ] || [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi

    # Create symlink
    ln -sfn "$plugin_dir" "$target_dir"
    echo -e "  ${GREEN}✓${NC} $plugin_name@qazuor v$version -> $target_dir"
}

update_settings() {
    local plugins_to_enable=("$@")

    # Ensure settings file exists
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo '{}' > "$SETTINGS_FILE"
    fi

    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"

    # Build enabledPlugins object
    local enabled_json="{}"
    for plugin_name in "${plugins_to_enable[@]}"; do
        enabled_json=$(echo "$enabled_json" | jq --arg key "${plugin_name}@qazuor" '. + {($key): true}') || {
            echo -e "${RED}ERROR: Failed to build plugin settings for $plugin_name${NC}"
            mv "$SETTINGS_FILE.bak" "$SETTINGS_FILE"
            return 1
        }
    done

    # Merge into settings.json (atomic write via temp file)
    local current tmp_file
    current=$(cat "$SETTINGS_FILE")
    tmp_file=$(mktemp "${SETTINGS_FILE}.XXXXXX")
    if echo "$current" | jq --argjson plugins "$enabled_json" \
        '.enabledPlugins = ((.enabledPlugins // {}) + $plugins)' > "$tmp_file"; then
        mv "$tmp_file" "$SETTINGS_FILE"
    else
        echo -e "${RED}ERROR: Failed to update settings.json${NC}"
        mv "$SETTINGS_FILE.bak" "$SETTINGS_FILE"
        rm -f "$tmp_file"
        return 1
    fi
    rm -f "$SETTINGS_FILE.bak"

    echo -e "${GREEN}Updated${NC} $SETTINGS_FILE with enabled plugins"
}

# ---------------------------------------------------------------------------
# Project-level installation functions
# ---------------------------------------------------------------------------

install_plugin_project() {
    local plugin_dir="$1"
    local claude_dir="$2"
    local plugin_name

    if [ ! -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
        echo -e "  ${RED}✗${NC} No plugin.json found in $plugin_dir"
        return 1
    fi

    plugin_name=$(jq -r '.name // empty' "$plugin_dir/.claude-plugin/plugin.json") || {
        echo -e "  ${RED}✗${NC} Failed to parse plugin.json in $plugin_dir"
        return 1
    }
    if [ -z "$plugin_name" ]; then
        echo -e "  ${RED}✗${NC} Missing 'name' in $plugin_dir/.claude-plugin/plugin.json"
        return 1
    fi

    local components=0

    # Agents: symlink individual .md files
    if [ -d "$plugin_dir/agents" ]; then
        mkdir -p "$claude_dir/agents"
        for f in "$plugin_dir/agents/"*.md; do
            [ -f "$f" ] || continue
            ln -sfn "$f" "$claude_dir/agents/$(basename "$f")"
            components=$((components + 1))
        done
    fi

    # Commands: symlink individual .md files
    if [ -d "$plugin_dir/commands" ]; then
        mkdir -p "$claude_dir/commands"
        for f in "$plugin_dir/commands/"*.md; do
            [ -f "$f" ] || continue
            ln -sfn "$f" "$claude_dir/commands/$(basename "$f")"
            components=$((components + 1))
        done
    fi

    # Skills: symlink individual skill directories
    if [ -d "$plugin_dir/skills" ]; then
        mkdir -p "$claude_dir/skills"
        for d in "$plugin_dir/skills/"*/; do
            [ -d "$d" ] || continue
            ln -sfn "$(cd "$d" && pwd)" "$claude_dir/skills/$(basename "$d")"
            components=$((components + 1))
        done
    fi

    # Docs: symlink individual .md files
    if [ -d "$plugin_dir/docs" ]; then
        mkdir -p "$claude_dir/docs"
        for f in "$plugin_dir/docs/"*.md; do
            [ -f "$f" ] || continue
            ln -sfn "$f" "$claude_dir/docs/$(basename "$f")"
            components=$((components + 1))
        done
    fi

    # Templates: symlink individual files
    if [ -d "$plugin_dir/templates" ]; then
        mkdir -p "$claude_dir/templates"
        for f in "$plugin_dir/templates/"*; do
            [ -e "$f" ] || continue
            ln -sfn "$f" "$claude_dir/templates/$(basename "$f")"
            components=$((components + 1))
        done
    fi

    echo -e "  ${GREEN}✓${NC} $plugin_name — $components components linked"
}

merge_hooks() {
    local plugin_dir="$1"
    local settings_file="$2"

    local hooks_file="$plugin_dir/hooks/hooks.json"
    [ -f "$hooks_file" ] || return 0

    # Replace ${CLAUDE_PLUGIN_ROOT} with absolute path to the plugin directory
    local plugin_abs_path
    plugin_abs_path=$(cd "$plugin_dir" && pwd)
    local hooks_content
    hooks_content=$(sed "s|\${CLAUDE_PLUGIN_ROOT}|$plugin_abs_path|g" "$hooks_file")

    # Plugin hooks.json uses the same event-keyed format as settings.json:
    # {"hooks": {"Stop": [{"hooks": [{"type":"command","command":"..."}]}]}}
    local new_hooks
    new_hooks=$(echo "$hooks_content" | jq '.hooks') || {
        echo -e "  ${YELLOW}!${NC} Failed to parse hooks from $(basename "$plugin_dir")"
        return 0
    }

    # Merge into settings file (append to existing event arrays)
    # First strip existing plugin hooks (makes re-install idempotent)
    local current
    current=$(cat "$settings_file")
    current=$(echo "$current" | jq '
        if .hooks then
            .hooks |= with_entries(
                .value |= map(select(._source != "qazuor-plugins"))
            )
        else . end
    ')

    # Merge with _source tag for clean uninstall
    local tmp_file
    tmp_file=$(mktemp "${settings_file}.XXXXXX")
    if echo "$current" | jq --argjson new "$new_hooks" '
        .hooks = ((.hooks // {}) as $existing |
            ($new | to_entries | reduce .[] as $entry ($existing;
                .[$entry.key] = ((.[$entry.key] // []) + ($entry.value | map(. + {"_source": "qazuor-plugins"})))
            ))
        )
    ' > "$tmp_file"; then
        mv "$tmp_file" "$settings_file"
    else
        echo -e "  ${YELLOW}!${NC} Failed to merge hooks from $(basename "$plugin_dir")"
        rm -f "$tmp_file"
        return 0
    fi

    local hook_count
    hook_count=$(echo "$hooks_content" | jq '.hooks | to_entries | map(.value | length) | add')
    echo -e "  ${GREEN}✓${NC} $(basename "$plugin_dir") — $hook_count hooks merged"
}

merge_mcp() {
    local plugin_dir="$1"
    local target_dir="$2"

    local mcp_source="$plugin_dir/.mcp.json"
    [ -f "$mcp_source" ] || return 0

    local mcp_target="$target_dir/.mcp.json"

    # Read source and strip metadata fields (keep only mcpServers)
    local mcp_servers
    mcp_servers=$(jq '.mcpServers // {}' "$mcp_source") || {
        echo -e "  ${YELLOW}!${NC} Failed to parse .mcp.json from $(basename "$plugin_dir")"
        return 0
    }

    if [ -f "$mcp_target" ]; then
        # Merge into existing .mcp.json
        local existing tmp_file
        existing=$(cat "$mcp_target")
        tmp_file=$(mktemp "${mcp_target}.XXXXXX")
        if echo "$existing" | jq --argjson new "$mcp_servers" '
            .mcpServers = ((.mcpServers // {}) + $new)
        ' > "$tmp_file"; then
            mv "$tmp_file" "$mcp_target"
        else
            echo -e "  ${YELLOW}!${NC} Failed to merge .mcp.json"
            rm -f "$tmp_file"
            return 0
        fi
    else
        # Create new .mcp.json
        echo "$mcp_servers" | jq '{mcpServers: .}' > "$mcp_target"
    fi

    local server_count
    server_count=$(echo "$mcp_servers" | jq 'length')
    echo -e "  ${GREEN}✓${NC} mcp-servers — $server_count servers merged into .mcp.json"
}

merge_mcp_user() {
    local plugin_dir="$1"
    local claude_json="$HOME/.claude.json"
    local mcp_source="$plugin_dir/.mcp.json"
    [ -f "$mcp_source" ] || return 0

    # Extract mcpServers
    local mcp_servers
    mcp_servers=$(jq '.mcpServers // {}' "$mcp_source") || {
        echo -e "  ${YELLOW}!${NC} Failed to parse .mcp.json"
        return 0
    }

    # Add "type": "stdio" where command exists and type is missing
    mcp_servers=$(echo "$mcp_servers" | jq '
        with_entries(
            if .value.command and (.value.type | not) then
                .value += {"type": "stdio"}
            else . end
        )
    ')

    # Ensure ~/.claude.json exists
    [ -f "$claude_json" ] || echo '{}' > "$claude_json"

    # Save manifest for uninstall (list of server names we offer to add)
    local manifest_dir="$CACHE_DIR"
    mkdir -p "$manifest_dir"
    echo "$mcp_servers" | jq '[keys[]]' > "$manifest_dir/.mcp-manifest.json"

    # Only add servers that DON'T already exist (user's config takes precedence)
    local current tmp_file
    current=$(cat "$claude_json")
    tmp_file=$(mktemp "${claude_json}.XXXXXX")
    if echo "$current" | jq --argjson new "$mcp_servers" '
        .mcpServers = ((.mcpServers // {}) as $existing |
            ($new | with_entries(select(.key as $k | $existing[$k] | not))) + $existing
        )
    ' > "$tmp_file"; then
        chmod 600 "$tmp_file"
        mv "$tmp_file" "$claude_json"
    else
        echo -e "  ${YELLOW}!${NC} Failed to merge MCP servers"
        rm -f "$tmp_file"
        return 0
    fi

    # Count how many were actually added
    local existing_count new_total added
    existing_count=$(echo "$current" | jq '.mcpServers // {} | length')
    new_total=$(jq '.mcpServers | length' "$claude_json")
    added=$((new_total - existing_count))
    local skipped=$(($(echo "$mcp_servers" | jq 'length') - added))

    echo -e "  ${GREEN}+${NC} $added servers added to ~/.claude.json"
    [ "$skipped" -gt 0 ] && echo -e "  ${YELLOW}~${NC} $skipped servers skipped (already configured)"
}

# ---------------------------------------------------------------------------
# External plugin helpers
# ---------------------------------------------------------------------------

is_plugin_installed() {
    local plugin_id="$1"
    local installed_file="$HOME/.claude/plugins/installed_plugins.json"
    [ -f "$installed_file" ] || return 1
    jq -e --arg id "$plugin_id" '.plugins[$id] | length > 0' "$installed_file" &>/dev/null
}

is_marketplace_added() {
    local name="$1"
    local known_file="$HOME/.claude/plugins/known_marketplaces.json"
    [ -f "$known_file" ] || return 1
    jq -e --arg name "$name" '.[$name]' "$known_file" &>/dev/null
}

setup_external_plugins() {
    local catalog="$SCRIPT_DIR/external-plugins.json"
    [ -f "$catalog" ] || return 0

    # Check if claude CLI is available
    if ! command -v claude &>/dev/null; then
        echo -e "${YELLOW}Claude CLI not found. Skipping external plugins.${NC}"
        return 0
    fi

    # Build list of not-yet-installed plugins
    local missing=()
    local total
    total=$(jq '.plugins | length' "$catalog")

    for i in $(seq 0 $((total - 1))); do
        local plugin_id name desc
        plugin_id=$(jq -r ".plugins[$i].pluginId" "$catalog")
        name=$(jq -r ".plugins[$i].name" "$catalog")
        desc=$(jq -r ".plugins[$i].description" "$catalog")

        if is_plugin_installed "$plugin_id"; then
            echo -e "  ${GREEN}✓${NC} $name — already installed"
        else
            missing+=("$i")
            echo -e "  ${YELLOW}○${NC} $name — $desc"
        fi
    done

    [ ${#missing[@]} -eq 0 ] && {
        echo -e "\n${GREEN}All recommended plugins are already installed!${NC}"
        return 0
    }

    echo ""
    echo -ne "Install ${#missing[@]} recommended plugin(s)? [Y/n]: "
    read -r answer
    [[ "$answer" =~ ^[Nn] ]] && return 0

    # Install each missing plugin
    for idx in "${missing[@]}"; do
        local name marketplace repo plugin_id
        name=$(jq -r ".plugins[$idx].name" "$catalog")
        marketplace=$(jq -r ".plugins[$idx].marketplace" "$catalog")
        repo=$(jq -r ".plugins[$idx].repo" "$catalog")
        plugin_id=$(jq -r ".plugins[$idx].pluginId" "$catalog")

        echo -e "\n${CYAN}Installing $name...${NC}"

        # Add marketplace if not present
        if ! is_marketplace_added "$marketplace"; then
            echo -e "  Adding marketplace $repo..."
            if claude plugin marketplace add "$repo" 2>&1; then
                echo -e "  ${GREEN}✓${NC} Marketplace added"
            else
                echo -e "  ${RED}✗${NC} Failed to add marketplace $repo — skipping $name"
                continue
            fi
        else
            echo -e "  ${GREEN}✓${NC} Marketplace already registered"
        fi

        # Install plugin
        echo -e "  Installing plugin..."
        if claude plugin install "$plugin_id" 2>&1; then
            echo -e "  ${GREEN}✓${NC} $name installed successfully"
        else
            echo -e "  ${RED}✗${NC} Failed to install $name"
        fi
    done
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
                echo -e "${RED}ERROR: --profile requires a value${NC}"
                usage
                exit 1
            fi
            PROFILE="$2"
            shift 2
            ;;
        --enable)
            if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
                echo -e "${RED}ERROR: --enable requires a plugin name${NC}"
                usage
                exit 1
            fi
            ENABLE_PLUGINS+=("$2")
            shift 2
            ;;
        --project)
            PROJECT_MODE=true
            # Check if next arg is a directory (not another flag)
            if [[ ${2:-} && ! ${2:-} == --* ]]; then
                PROJECT_DIR="$2"
                shift 2
            else
                PROJECT_DIR="$(pwd)"
                shift
            fi
            ;;
        --setup-mcp)
            SETUP_MCP=true
            shift
            ;;
        --skip-extras)
            SKIP_EXTRAS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required but not installed.${NC}"
    echo "Install it with: sudo apt install jq (Linux) or brew install jq (macOS)"
    exit 1
fi

# Validate plugins directory exists and is not empty
if [ ! -d "$PLUGINS_DIR" ]; then
    echo -e "${RED}ERROR: Plugins directory not found: $PLUGINS_DIR${NC}"
    exit 1
fi
plugin_count=$(find "$PLUGINS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
if [ "$plugin_count" -eq 0 ]; then
    echo -e "${RED}ERROR: No plugins found in $PLUGINS_DIR${NC}"
    exit 1
fi

# Validate project directory if project mode
if [ "$PROJECT_MODE" = true ]; then
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}ERROR: Project directory does not exist: $PROJECT_DIR${NC}"
        exit 1
    fi
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
fi

echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Claude Code Plugins — Installer    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

if [ "$PROJECT_MODE" = true ]; then
    echo -e "${BLUE}Mode:${NC} Project-level"
    echo -e "${BLUE}Target:${NC} $PROJECT_DIR/.claude/"
else
    echo -e "${BLUE}Mode:${NC} User-level"
    echo -e "${BLUE}Target:${NC} $CACHE_DIR"
fi
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

    # Read profile plugins and validate they all exist before installing
    mapfile -t profile_plugins < <(jq -r '.plugins[]' "$local_profile")
    for p in "${profile_plugins[@]}"; do
        if [ ! -d "$PLUGINS_DIR/$p" ]; then
            echo -e "${RED}ERROR: Profile '$PROFILE' references non-existent plugin: $p${NC}"
            exit 1
        fi
    done
    PLUGINS_TO_INSTALL=("${profile_plugins[@]}")
elif [ ${#ENABLE_PLUGINS[@]} -gt 0 ]; then
    PLUGINS_TO_INSTALL=("${ENABLE_PLUGINS[@]}")
else
    # Default: install all plugins
    echo -e "${YELLOW}No profile or plugins specified. Installing all plugins.${NC}"
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        [ -d "$plugin_dir" ] || continue
        if [ -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
            local_name="$(jq -r '.name // empty' "$plugin_dir/.claude-plugin/plugin.json")" || continue
            if [ -n "$local_name" ]; then
                PLUGINS_TO_INSTALL+=("$local_name")
            fi
        fi
    done
fi

if [ ${#PLUGINS_TO_INSTALL[@]} -eq 0 ]; then
    echo -e "${YELLOW}No plugins to install.${NC}"
    exit 0
fi

echo -e "${BLUE}Plugins:${NC} ${PLUGINS_TO_INSTALL[*]}"
echo ""

# ---------------------------------------------------------------------------
# Dry run: show what would happen and exit
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}[DRY RUN] Would install the following:${NC}"
    echo ""
    for plugin_name in "${PLUGINS_TO_INSTALL[@]}"; do
        plugin_dir="$PLUGINS_DIR/$plugin_name"
        [ -d "$plugin_dir" ] || continue
        echo -e "  ${GREEN}Plugin:${NC} $plugin_name"
        if [ "$PROJECT_MODE" = true ]; then
            for comp in agents commands skills docs templates; do
                if [ -d "$plugin_dir/$comp" ]; then
                    count=$(find "$plugin_dir/$comp" -maxdepth 1 \( -name '*.md' -o -type d ! -path "$plugin_dir/$comp" \) 2>/dev/null | wc -l)
                    [ "$count" -gt 0 ] && echo "    $comp: $count"
                fi
            done
            [ -f "$plugin_dir/hooks/hooks.json" ] && echo "    hooks: merged into .claude/settings.local.json"
            [ -f "$plugin_dir/.mcp.json" ] && echo "    mcp: merged into .mcp.json"
        else
            version=$(jq -r '.version // "0.0.0"' "$plugin_dir/.claude-plugin/plugin.json") || true
            echo "    -> $CACHE_DIR/$plugin_name/$version"
            [ -f "$plugin_dir/hooks/hooks.json" ] && echo "    hooks: merged into ~/.claude/settings.json"
            [ -f "$plugin_dir/.mcp.json" ] && echo "    mcp: merged into ~/.claude.json (skip existing)"
        fi
    done
    # Show external plugins that would be offered
    if [ "$SKIP_EXTRAS" = false ] && [ -f "$SCRIPT_DIR/external-plugins.json" ]; then
        echo ""
        echo -e "  ${CYAN}Would also offer to install:${NC}"
        jq -r '.plugins[] | "    \(.name) — \(.description)"' "$SCRIPT_DIR/external-plugins.json"
    fi
    echo ""
    echo -e "${YELLOW}No changes were made (dry run).${NC}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Install plugins
# ---------------------------------------------------------------------------
echo -e "${CYAN}Installing plugins...${NC}"
INSTALLED=()

if [ "$PROJECT_MODE" = true ]; then
    # --- Project-level installation ---
    CLAUDE_DIR="$PROJECT_DIR/.claude"
    mkdir -p "$CLAUDE_DIR"

    for plugin_name in "${PLUGINS_TO_INSTALL[@]}"; do
        plugin_dir="$PLUGINS_DIR/$plugin_name"
        if [ -d "$plugin_dir" ]; then
            if install_plugin_project "$plugin_dir" "$CLAUDE_DIR"; then
                INSTALLED+=("$plugin_name")
            else
                echo -e "  ${YELLOW}!${NC} Failed to install '$plugin_name', skipping"
            fi
        else
            echo -e "  ${YELLOW}!${NC} Plugin '$plugin_name' not found in $PLUGINS_DIR"
        fi
    done
    echo ""

    # Merge hooks into .claude/settings.local.json (local because paths are absolute)
    HOOKS_FOUND=false
    for plugin_name in "${INSTALLED[@]}"; do
        plugin_dir="$PLUGINS_DIR/$plugin_name"
        if [ -f "$plugin_dir/hooks/hooks.json" ]; then
            if [ "$HOOKS_FOUND" = false ]; then
                echo -e "${CYAN}Merging hooks...${NC}"
                LOCAL_SETTINGS="$CLAUDE_DIR/settings.local.json"
                if [ ! -f "$LOCAL_SETTINGS" ]; then
                    echo '{}' > "$LOCAL_SETTINGS"
                fi
                HOOKS_FOUND=true
            fi
            merge_hooks "$plugin_dir" "$LOCAL_SETTINGS"
        fi
    done
    if [ "$HOOKS_FOUND" = true ]; then
        echo ""
    fi

    # Merge MCP servers into .mcp.json at project root
    for plugin_name in "${INSTALLED[@]}"; do
        plugin_dir="$PLUGINS_DIR/$plugin_name"
        if [ -f "$plugin_dir/.mcp.json" ]; then
            echo -e "${CYAN}Merging MCP servers...${NC}"
            merge_mcp "$plugin_dir" "$PROJECT_DIR"
            echo ""
            break  # Only one plugin has .mcp.json
        fi
    done

else
    # --- User-level installation ---
    for plugin_name in "${PLUGINS_TO_INSTALL[@]}"; do
        plugin_dir="$PLUGINS_DIR/$plugin_name"
        if [ -d "$plugin_dir" ]; then
            if install_plugin "$plugin_dir"; then
                INSTALLED+=("$plugin_name")
            else
                echo -e "  ${YELLOW}!${NC} Failed to install '$plugin_name', skipping"
            fi
        else
            echo -e "  ${YELLOW}!${NC} Plugin '$plugin_name' not found in $PLUGINS_DIR"
        fi
    done
    echo ""

    # Update settings.json
    if [ ${#INSTALLED[@]} -gt 0 ]; then
        echo -e "${CYAN}Updating settings...${NC}"
        update_settings "${INSTALLED[@]}"
        echo ""
    fi

    # Merge hooks into ~/.claude/settings.json
    HOOKS_FOUND=false
    for plugin_name in "${INSTALLED[@]}"; do
        plugin_dir="$PLUGINS_DIR/$plugin_name"
        if [ -f "$plugin_dir/hooks/hooks.json" ]; then
            if [ "$HOOKS_FOUND" = false ]; then
                echo -e "${CYAN}Merging hooks...${NC}"
                HOOKS_FOUND=true
            fi
            merge_hooks "$plugin_dir" "$SETTINGS_FILE"
        fi
    done
    [ "$HOOKS_FOUND" = true ] && echo ""

    # Merge MCP servers into ~/.claude.json
    for plugin_name in "${INSTALLED[@]}"; do
        plugin_dir="$PLUGINS_DIR/$plugin_name"
        if [ -f "$plugin_dir/.mcp.json" ]; then
            echo -e "${CYAN}Merging MCP servers...${NC}"
            merge_mcp_user "$plugin_dir"
            echo ""
            break  # Only one plugin has .mcp.json
        fi
    done
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

    if [ "$PROJECT_MODE" = true ]; then
        ENV_FILE="$PROJECT_DIR/.claude/.env"
    else
        ENV_FILE="$HOME/.claude/.env.mcp"
    fi
    # Create .env file with restricted permissions from the start
    if [ ! -f "$ENV_FILE" ]; then
        mkdir -p "$(dirname "$ENV_FILE")"
        install -m 600 /dev/null "$ENV_FILE"
    fi

    for key in "${!MCP_KEYS[@]}"; do
        desc="${MCP_KEYS[$key]}"
        # Escape key for safe grep usage (handles regex special chars)
        # shellcheck disable=SC2016
        escaped_key=$(printf '%s' "$key" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
        if grep -q "^${escaped_key}=" "$ENV_FILE" 2>/dev/null; then
            echo -ne "  ${desc} [${GREEN}configured${NC}] (Enter to keep, or new value): "
        else
            echo -ne "  ${desc}: "
        fi
        read -r value
        if [ -n "$value" ]; then
            # Remove existing and add new
            env_tmp=$(mktemp "${ENV_FILE}.XXXXXX")
            grep -v "^${escaped_key}=" "$ENV_FILE" > "$env_tmp" 2>/dev/null || true
            echo "${key}=${value}" >> "$env_tmp"
            mv "$env_tmp" "$ENV_FILE"
            chmod 600 "$ENV_FILE"
            echo -e "    ${GREEN}✓${NC} Saved"
        fi
    done
    chmod 600 "$ENV_FILE"
    echo ""
    echo -e "${GREEN}API keys saved to${NC} $ENV_FILE"
    echo ""
fi

# External plugins setup
if [ "$SKIP_EXTRAS" = false ] && [ "$DRY_RUN" = false ]; then
    echo ""
    echo -e "${CYAN}Recommended Third-Party Plugins${NC}"
    echo "The following plugins are recommended alongside this toolkit:"
    echo ""
    setup_external_plugins
    echo ""
fi

# Summary
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Installation Complete!         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""

if [ "$PROJECT_MODE" = true ]; then
    echo -e "Installed ${GREEN}${#INSTALLED[@]}${NC} plugins into $PROJECT_DIR/.claude/"
    echo ""

    # Count installed components
    agent_count=$(find "$PROJECT_DIR/.claude/agents" -maxdepth 1 -name '*.md' -type l 2>/dev/null | wc -l)
    cmd_count=$(find "$PROJECT_DIR/.claude/commands" -maxdepth 1 -name '*.md' -type l 2>/dev/null | wc -l)
    skill_count=$(find "$PROJECT_DIR/.claude/skills" -maxdepth 1 -type l 2>/dev/null | wc -l)
    doc_count=$(find "$PROJECT_DIR/.claude/docs" -maxdepth 1 -name '*.md' -type l 2>/dev/null | wc -l)
    tmpl_count=$(find "$PROJECT_DIR/.claude/templates" -maxdepth 1 -type l 2>/dev/null | wc -l)

    echo "Components installed:"
    [ "$agent_count" -gt 0 ] && echo -e "  Agents:    ${GREEN}$agent_count${NC}"
    [ "$cmd_count" -gt 0 ]   && echo -e "  Commands:  ${GREEN}$cmd_count${NC}"
    [ "$skill_count" -gt 0 ] && echo -e "  Skills:    ${GREEN}$skill_count${NC}"
    [ "$doc_count" -gt 0 ]   && echo -e "  Docs:      ${GREEN}$doc_count${NC}"
    [ "$tmpl_count" -gt 0 ]  && echo -e "  Templates: ${GREEN}$tmpl_count${NC}"
    echo ""

    echo "Files created:"
    echo "  $PROJECT_DIR/.claude/          (symlinked components)"
    [ -f "$PROJECT_DIR/.claude/settings.local.json" ] && \
        echo "  $PROJECT_DIR/.claude/settings.local.json (hooks — gitignore recommended)"
    [ -f "$PROJECT_DIR/.mcp.json" ] && \
        echo "  $PROJECT_DIR/.mcp.json         (MCP server configs)"
    echo ""
    echo "Next steps:"
    echo "  1. cd $PROJECT_DIR && claude"
    echo "  2. Try /help to see available commands"
    echo ""
    echo -e "${YELLOW}Note:${NC} Symlinks point to the plugin repo. Run 'git pull' there to update."
    echo -e "${YELLOW}Note:${NC} Consider adding .claude/settings.local.json to .gitignore (contains absolute paths)."
else
    echo -e "Installed ${GREEN}${#INSTALLED[@]}${NC} plugins to $CACHE_DIR"
    echo ""
    echo "Files updated:"
    echo "  $CACHE_DIR/         (plugin symlinks)"
    echo "  $SETTINGS_FILE      (enabledPlugins + hooks)"
    [ -f "$HOME/.claude.json" ] && \
        echo "  ~/.claude.json               (MCP servers)"
    echo ""
    echo "Next steps:"
    echo "  1. Open Claude Code in any project"
    echo "  2. Try /help to see available commands"
    echo "  3. Try /quality-check to validate your code"
    echo ""
    echo "To update: cd $REPO_DIR && git pull"
    echo "  (symlinks mean updates are instant)"
fi
