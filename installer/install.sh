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
YES_MODE=false

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
    echo "  --yes, -y            Non-interactive mode (accept defaults, skip prompts)"
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

# Build a list of all components available at user level from enabled plugins
# Populates global arrays: USER_AGENTS, USER_COMMANDS, USER_SKILLS, USER_DOCS, USER_TEMPLATES
build_user_level_component_index() {
    USER_AGENTS=()
    USER_COMMANDS=()
    USER_SKILLS=()
    USER_DOCS=()
    USER_TEMPLATES=()

    local settings_file="$HOME/.claude/settings.json"
    [ -f "$settings_file" ] || return 0

    # Get enabled plugins
    local enabled_plugins
    enabled_plugins=$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$settings_file" 2>/dev/null)
    [ -z "$enabled_plugins" ] && return 0

    # For each enabled plugin, find its components
    while IFS= read -r plugin_key; do
        [ -z "$plugin_key" ] && continue

        # Extract plugin name and author (format: name@author)
        local plugin_name author
        plugin_name="${plugin_key%@*}"
        author="${plugin_key#*@}"

        # Find plugin directory in cache
        local cache_base="$HOME/.claude/plugins/cache/$author/$plugin_name"
        [ -d "$cache_base" ] || continue

        # Get the latest version directory (or any version)
        local plugin_dir=""
        for version_dir in "$cache_base"/*/; do
            [ -d "$version_dir" ] && plugin_dir="$version_dir" && break
        done
        [ -z "$plugin_dir" ] && continue

        # Index agents
        if [ -d "$plugin_dir/agents" ]; then
            for f in "$plugin_dir/agents/"*.md; do
                [ -f "$f" ] && USER_AGENTS+=("$(basename "$f")")
            done
        fi

        # Index commands
        if [ -d "$plugin_dir/commands" ]; then
            for f in "$plugin_dir/commands/"*.md; do
                [ -f "$f" ] && USER_COMMANDS+=("$(basename "$f")")
            done
        fi

        # Index skills
        if [ -d "$plugin_dir/skills" ]; then
            for d in "$plugin_dir/skills/"*/; do
                [ -d "$d" ] && USER_SKILLS+=("$(basename "$d")")
            done
        fi

        # Index docs
        if [ -d "$plugin_dir/docs" ]; then
            for f in "$plugin_dir/docs/"*.md; do
                [ -f "$f" ] && USER_DOCS+=("$(basename "$f")")
            done
        fi

        # Index templates
        if [ -d "$plugin_dir/templates" ]; then
            for f in "$plugin_dir/templates/"*; do
                [ -e "$f" ] && USER_TEMPLATES+=("$(basename "$f")")
            done
        fi
    done <<< "$enabled_plugins"
}

# Check if a component exists in an array
component_exists_at_user_level() {
    local component="$1"
    shift
    local arr=("$@")
    for item in "${arr[@]}"; do
        [ "$item" = "$component" ] && return 0
    done
    return 1
}

install_plugin_project() {
    local plugin_dir="$1"
    local claude_dir="$2"
    local skip_user_components="${3:-false}"
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
    local skipped=0

    # Agents: symlink individual .md files
    if [ -d "$plugin_dir/agents" ]; then
        mkdir -p "$claude_dir/agents"
        for f in "$plugin_dir/agents/"*.md; do
            [ -f "$f" ] || continue
            local fname
            fname=$(basename "$f")
            if [ "$skip_user_components" = true ] && component_exists_at_user_level "$fname" "${USER_AGENTS[@]}"; then
                skipped=$((skipped + 1))
                continue
            fi
            ln -sfn "$f" "$claude_dir/agents/$fname"
            components=$((components + 1))
        done
    fi

    # Commands: symlink individual .md files
    if [ -d "$plugin_dir/commands" ]; then
        mkdir -p "$claude_dir/commands"
        for f in "$plugin_dir/commands/"*.md; do
            [ -f "$f" ] || continue
            local fname
            fname=$(basename "$f")
            if [ "$skip_user_components" = true ] && component_exists_at_user_level "$fname" "${USER_COMMANDS[@]}"; then
                skipped=$((skipped + 1))
                continue
            fi
            ln -sfn "$f" "$claude_dir/commands/$fname"
            components=$((components + 1))
        done
    fi

    # Skills: symlink individual skill directories
    if [ -d "$plugin_dir/skills" ]; then
        mkdir -p "$claude_dir/skills"
        for d in "$plugin_dir/skills/"*/; do
            [ -d "$d" ] || continue
            local dname
            dname=$(basename "$d")
            if [ "$skip_user_components" = true ] && component_exists_at_user_level "$dname" "${USER_SKILLS[@]}"; then
                skipped=$((skipped + 1))
                continue
            fi
            ln -sfn "$(cd "$d" && pwd)" "$claude_dir/skills/$dname"
            components=$((components + 1))
        done
    fi

    # Docs: symlink individual .md files
    if [ -d "$plugin_dir/docs" ]; then
        mkdir -p "$claude_dir/docs"
        for f in "$plugin_dir/docs/"*.md; do
            [ -f "$f" ] || continue
            local fname
            fname=$(basename "$f")
            if [ "$skip_user_components" = true ] && component_exists_at_user_level "$fname" "${USER_DOCS[@]}"; then
                skipped=$((skipped + 1))
                continue
            fi
            ln -sfn "$f" "$claude_dir/docs/$fname"
            components=$((components + 1))
        done
    fi

    # Templates: symlink individual files
    if [ -d "$plugin_dir/templates" ]; then
        mkdir -p "$claude_dir/templates"
        for f in "$plugin_dir/templates/"*; do
            [ -e "$f" ] || continue
            local fname
            fname=$(basename "$f")
            if [ "$skip_user_components" = true ] && component_exists_at_user_level "$fname" "${USER_TEMPLATES[@]}"; then
                skipped=$((skipped + 1))
                continue
            fi
            ln -sfn "$f" "$claude_dir/templates/$fname"
            components=$((components + 1))
        done
    fi

    # Report results
    if [ "$components" -eq 0 ] && [ "$skipped" -gt 0 ]; then
        echo -e "  ${GREEN}~${NC} $plugin_name — all $skipped components already at user level"
    elif [ "$skipped" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} $plugin_name — $components linked, $skipped skipped (user level)"
    else
        echo -e "  ${GREEN}✓${NC} $plugin_name — $components components linked"
    fi
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
    # Strip only THIS plugin's event keys (not all qazuor-plugins hooks)
    # to make re-install idempotent without clobbering other plugins' hooks
    local current event_keys
    current=$(cat "$settings_file")
    event_keys=$(echo "$new_hooks" | jq '[keys[]]')
    current=$(echo "$current" | jq --argjson keys "$event_keys" '
        if .hooks then
            .hooks |= with_entries(
                if (.key | IN($keys[])) then
                    .value |= map(select(._source != "qazuor-plugins"))
                else . end
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
    local skip_keys="${3:-[]}"   # JSON array of server names to skip (dedup)

    local mcp_source="$plugin_dir/.mcp.json"
    [ -f "$mcp_source" ] || return 0

    local mcp_target="$target_dir/.mcp.json"

    # Read source and strip metadata fields (keep only mcpServers)
    local mcp_servers
    mcp_servers=$(jq '.mcpServers // {}' "$mcp_source") || {
        echo -e "  ${YELLOW}!${NC} Failed to parse .mcp.json from $(basename "$plugin_dir")"
        return 0
    }

    # Filter out servers already configured at user level
    local total_before
    total_before=$(echo "$mcp_servers" | jq 'length')
    if [ "$skip_keys" != "[]" ]; then
        mcp_servers=$(echo "$mcp_servers" | jq --argjson skip "$skip_keys" '
            with_entries(select(.key as $k | $skip | index($k) | not))
        ')
    fi

    # If nothing left to merge, report and return
    local remaining
    remaining=$(echo "$mcp_servers" | jq 'length')
    if [ "$remaining" -eq 0 ]; then
        echo -e "  ${GREEN}~${NC} mcp-servers -- all $total_before servers already configured at user level"
        return 0
    fi

    local skipped=$((total_before - remaining))

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

    echo -e "  ${GREEN}✓${NC} mcp-servers — $remaining servers merged into .mcp.json"
    if [ "$skipped" -gt 0 ]; then
        echo -e "  ${YELLOW}~${NC} $skipped servers skipped (already configured at user level)"
    fi
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
    if [ "$skipped" -gt 0 ]; then
        echo -e "  ${YELLOW}~${NC} $skipped servers skipped (already configured)"
    fi
}

GLOBAL_RULES_MARKER_BEGIN="<!-- qazuor-plugins:global-rules:begin -->"
GLOBAL_RULES_MARKER_END="<!-- qazuor-plugins:global-rules:end -->"

has_qazuor_global_rules() {
    local file="$1"
    [ -f "$file" ] && grep -qF "$GLOBAL_RULES_MARKER_BEGIN" "$file" 2>/dev/null
}

inject_global_rules() {
    local target_file="$1"
    local lang="$2"
    local rules_template="$REPO_DIR/plugins/core/templates/global-rules-block.md.template"

    if [ ! -f "$rules_template" ]; then
        echo -e "  ${YELLOW}!${NC} Rules template not found: $rules_template"
        return 1
    fi

    # Generate the rules block into a temp file for safe multiline handling
    local rules_file
    rules_file=$(mktemp "${target_file}.rules.XXXXXX")
    _CLEANUP_FILES+=("$rules_file")
    sed "s/{{PREFERRED_LANGUAGE}}/$lang/g" "$rules_template" > "$rules_file"

    mkdir -p "$(dirname "$target_file")"

    if has_qazuor_global_rules "$target_file"; then
        # Replace existing block (idempotent update)
        local tmp_file
        tmp_file=$(mktemp "${target_file}.XXXXXX")
        _CLEANUP_FILES+=("$tmp_file")
        awk -v begin="$GLOBAL_RULES_MARKER_BEGIN" -v end="$GLOBAL_RULES_MARKER_END" -v rfile="$rules_file" '
            $0 == begin { while ((getline line < rfile) > 0) print line; close(rfile); skip=1; next }
            $0 == end   { skip=0; next }
            !skip       { print }
        ' "$target_file" > "$tmp_file"
        mv "$tmp_file" "$target_file"
    else
        # Append block to end of file
        if [ -f "$target_file" ] && [ -s "$target_file" ]; then
            # Ensure a blank line before the block
            printf '\n' >> "$target_file"
            cat "$rules_file" >> "$target_file"
        else
            cat "$rules_file" > "$target_file"
        fi
    fi
    rm -f "$rules_file"
}

setup_claude_md() {
    local claude_md="$HOME/.claude/CLAUDE.md"
    local template="$REPO_DIR/plugins/core/templates/global.md.template"
    local rules_template="$REPO_DIR/plugins/core/templates/global-rules-block.md.template"

    # Check if templates exist
    if [ ! -f "$template" ]; then
        echo -e "  ${YELLOW}!${NC} Template not found: $template"
        return 0
    fi
    if [ ! -f "$rules_template" ]; then
        echo -e "  ${YELLOW}!${NC} Rules template not found: $rules_template"
        return 0
    fi

    # 3-state detection: missing | has_our_rules | custom
    local state="missing"
    if [ -f "$claude_md" ] && [ -s "$claude_md" ]; then
        if has_qazuor_global_rules "$claude_md"; then
            state="has_our_rules"
        elif grep -q "Describe your project here\.\.\." "$claude_md" 2>/dev/null; then
            state="missing"  # default placeholder counts as missing
        else
            state="custom"
        fi
    fi

    echo -e "${CYAN}Setting up ~/.claude/CLAUDE.md...${NC}"
    echo ""

    # Skip interactive prompts in YES_MODE
    if [ "$YES_MODE" = true ]; then
        echo -e "  ${YELLOW}~${NC} Skipped (non-interactive mode)"
        return 0
    fi

    case "$state" in
        missing)
            echo "  Your CLAUDE.md is empty or has the default placeholder."
            echo "  We can populate it with global development instructions"
            echo "  (coding standards, TDD, TypeScript, commit conventions, etc.)."
            echo ""
            echo -ne "  Generate global CLAUDE.md? [Y/n]: "
            read -r answer
            [[ "$answer" =~ ^[Nn] ]] && return 0

            echo ""
            echo -ne "  Preferred language for Claude responses [English]: "
            read -r lang
            lang="${lang:-English}"

            mkdir -p "$(dirname "$claude_md")"
            sed "s/{{PREFERRED_LANGUAGE}}/$lang/g" "$template" > "$claude_md"
            echo ""
            echo -e "  ${GREEN}✓${NC} Generated ~/.claude/CLAUDE.md (language: $lang)"
            ;;

        has_our_rules)
            echo "  Your CLAUDE.md already contains our global rules."
            echo ""
            echo -ne "  Update rules to latest version? [Y/n]: "
            read -r answer
            [[ "$answer" =~ ^[Nn] ]] && return 0

            echo ""
            echo -ne "  Preferred language for Claude responses [English]: "
            read -r lang
            lang="${lang:-English}"

            inject_global_rules "$claude_md" "$lang"
            echo ""
            echo -e "  ${GREEN}✓${NC} Updated global rules in ~/.claude/CLAUDE.md (language: $lang)"
            ;;

        custom)
            echo "  Your CLAUDE.md has custom content."
            echo "  We can add our global development rules alongside your content."
            echo ""
            echo "  [S]kip  — Don't touch (default)"
            echo "  [O]verwrite — Replace with our template"
            echo "  [M]erge — Append global rules to your existing content"
            echo ""
            echo -ne "  Choose [S/o/m]: "
            read -r choice
            choice="${choice:-S}"

            case "$choice" in
                [Oo])
                    echo ""
                    echo -ne "  Preferred language for Claude responses [English]: "
                    read -r lang
                    lang="${lang:-English}"

                    sed "s/{{PREFERRED_LANGUAGE}}/$lang/g" "$template" > "$claude_md"
                    echo ""
                    echo -e "  ${GREEN}✓${NC} Replaced ~/.claude/CLAUDE.md (language: $lang)"
                    ;;
                [Mm])
                    echo ""
                    echo -ne "  Preferred language for Claude responses [English]: "
                    read -r lang
                    lang="${lang:-English}"

                    inject_global_rules "$claude_md" "$lang"
                    echo ""
                    echo -e "  ${GREEN}✓${NC} Merged global rules into ~/.claude/CLAUDE.md (language: $lang)"
                    ;;
                *)
                    echo -e "  ${YELLOW}~${NC} Skipped CLAUDE.md setup"
                    return 0
                    ;;
            esac
            ;;
    esac
}

is_new_project() {
    local project_dir="$1"
    # A project is "new" if it has no meaningful code files
    # Check for common indicators of existing development
    local indicators=0

    # Check for package.json with dependencies
    if [ -f "$project_dir/package.json" ] && \
       jq -e '.dependencies or .devDependencies' "$project_dir/package.json" &>/dev/null; then
        indicators=$((indicators + 1))
    fi

    # Check for src/ or app/ directories with files
    if [ -d "$project_dir/src" ] && [ "$(find "$project_dir/src" -type f 2>/dev/null | head -1)" ]; then
        indicators=$((indicators + 1))
    fi
    if [ -d "$project_dir/app" ] && [ "$(find "$project_dir/app" -type f 2>/dev/null | head -1)" ]; then
        indicators=$((indicators + 1))
    fi

    # Check for common config files that indicate active development
    for cfg in tsconfig.json vite.config.ts next.config.js astro.config.mjs; do
        [ -f "$project_dir/$cfg" ] && indicators=$((indicators + 1))
    done

    # New if fewer than 2 indicators
    [ "$indicators" -lt 2 ]
}

setup_project_claude_md() {
    local project_dir="$1"
    # CLAUDE.md goes in project root (standard location)
    local claude_md="$project_dir/CLAUDE.md"
    # Also check .claude/ location for backwards compatibility
    local claude_md_alt="$project_dir/.claude/CLAUDE.md"

    # Skip if project already has a CLAUDE.md with real content (check both locations)
    for check_path in "$claude_md" "$claude_md_alt"; do
        if [ -f "$check_path" ] && [ -s "$check_path" ]; then
            if ! grep -q "Describe your project here\.\.\." "$check_path" 2>/dev/null; then
                echo -e "${CYAN}Project CLAUDE.md${NC}"
                echo -e "  ${GREEN}✓${NC} $check_path already exists with content — skipping"
                echo ""
                return 0
            fi
        fi
    done

    echo -e "${CYAN}Setting up project CLAUDE.md...${NC}"
    echo ""

    # Skip interactive prompts in YES_MODE
    if [ "$YES_MODE" = true ]; then
        echo -e "  ${YELLOW}~${NC} Skipped (non-interactive mode)"
        return 0
    fi

    echo -ne "  Generate project CLAUDE.md? [Y/n]: "
    read -r answer
    [[ "$answer" =~ ^[Nn] ]] && return 0

    # Determine if new or existing project
    if is_new_project "$project_dir"; then
        setup_project_claude_md_new "$project_dir" "$claude_md"
    else
        setup_project_claude_md_existing "$project_dir" "$claude_md"
    fi
}

setup_project_claude_md_new() {
    local project_dir="$1"
    local claude_md="$2"
    local template="$REPO_DIR/plugins/core/templates/project-minimal.md.template"

    if [ ! -f "$template" ]; then
        echo -e "  ${YELLOW}!${NC} Template not found: $template"
        return 0
    fi

    echo ""
    echo "  This looks like a new project. We'll create a minimal CLAUDE.md"
    echo "  with placeholders for you to fill in later."
    echo ""
    echo "  Fill in the following (press Enter to keep defaults):"
    echo ""

    # Essential questions only
    echo -ne "  Project name [$(basename "$project_dir")]: "
    read -r proj_name
    proj_name="${proj_name:-$(basename "$project_dir")}"

    echo -ne "  Project description [A software project]: "
    read -r proj_desc
    proj_desc="${proj_desc:-A software project}"

    echo -ne "  Test framework [Vitest]: "
    read -r test_fw
    test_fw="${test_fw:-Vitest}"

    echo -ne "  Package manager [pnpm]: "
    read -r pkg_mgr
    pkg_mgr="${pkg_mgr:-pnpm}"

    echo -ne "  Formatter/linter [Biome]: "
    read -r formatter
    formatter="${formatter:-Biome}"

    echo -ne "  Test location [test/ directory mirroring src/]: "
    read -r test_loc
    test_loc="${test_loc:-test/ directory mirroring src/}"

    echo -ne "  Config method [environment variables]: "
    read -r config_method
    config_method="${config_method:-environment variables}"

    echo -ne "  Deployment platform [Vercel]: "
    read -r deploy_platform
    deploy_platform="${deploy_platform:-Vercel}"

    echo -ne "  CI/CD [GitHub Actions]: "
    read -r cicd
    cicd="${cicd:-GitHub Actions}"

    echo -ne "  Preferred language for Claude responses [Spanish]: "
    read -r preferred_lang
    preferred_lang="${preferred_lang:-Spanish}"

    echo -ne "  Preferred language for code/comments/docs [English]: "
    read -r code_lang
    code_lang="${code_lang:-English}"

    echo ""

    # Generate from template (CLAUDE.md goes in project root)
    sed \
        -e "s|{{PROJECT_NAME}}|$proj_name|g" \
        -e "s|{{PROJECT_DESCRIPTION}}|$proj_desc|g" \
        -e "s|{{TEST_FRAMEWORK}}|$test_fw|g" \
        -e "s|{{PACKAGE_MANAGER}}|$pkg_mgr|g" \
        -e "s|{{FORMATTER}}|$formatter|g" \
        -e "s|{{TEST_LOCATION}}|$test_loc|g" \
        -e "s|{{CONFIG_METHOD}}|$config_method|g" \
        -e "s|{{DEPLOYMENT_PLATFORM}}|$deploy_platform|g" \
        -e "s|{{CI_CD}}|$cicd|g" \
        -e "s|{{PREFERRED_LANG}}|$preferred_lang|g" \
        -e "s|{{CODE_LANG}}|$code_lang|g" \
        "$template" > "$claude_md"

    # Append global rules if user-level doesn't have them
    local user_claude_md="$HOME/.claude/CLAUDE.md"
    if ! has_qazuor_global_rules "$user_claude_md"; then
        inject_global_rules "$claude_md" "$preferred_lang"
    fi

    echo -e "  ${GREEN}✓${NC} Generated $claude_md"
    echo ""
    echo -e "  ${YELLOW}Important:${NC} The generated CLAUDE.md has TODO placeholders."
    echo -e "  Please edit $claude_md to complete the project configuration."
    echo ""
}

detect_project_info() {
    local project_dir="$1"

    # Initialize with defaults
    DETECTED_NAME="$(basename "$project_dir")"
    DETECTED_DESC="A software project"
    DETECTED_TEST_FW="Vitest"
    DETECTED_PKG_MGR="pnpm"
    DETECTED_FORMATTER="Biome"
    DETECTED_TEST_LOC="test/ directory mirroring src/"
    DETECTED_CONFIG="environment variables"
    DETECTED_DEPLOY="Vercel"
    DETECTED_CICD="GitHub Actions"

    # Try to read package.json
    local pkg_json="$project_dir/package.json"
    if [ -f "$pkg_json" ]; then
        # Project name from package.json
        local pkg_name
        pkg_name=$(jq -r '.name // empty' "$pkg_json" 2>/dev/null)
        [ -n "$pkg_name" ] && DETECTED_NAME="$pkg_name"

        # Description from package.json
        local pkg_desc
        pkg_desc=$(jq -r '.description // empty' "$pkg_json" 2>/dev/null)
        [ -n "$pkg_desc" ] && DETECTED_DESC="$pkg_desc"

        # Detect package manager from lockfiles
        if [ -f "$project_dir/pnpm-lock.yaml" ]; then
            DETECTED_PKG_MGR="pnpm"
        elif [ -f "$project_dir/yarn.lock" ]; then
            DETECTED_PKG_MGR="yarn"
        elif [ -f "$project_dir/bun.lockb" ]; then
            DETECTED_PKG_MGR="bun"
        elif [ -f "$project_dir/package-lock.json" ]; then
            DETECTED_PKG_MGR="npm"
        fi

        # Detect test framework from devDependencies
        local dev_deps
        dev_deps=$(jq -r '.devDependencies // {} | keys[]' "$pkg_json" 2>/dev/null)
        if echo "$dev_deps" | grep -q "^vitest$"; then
            DETECTED_TEST_FW="Vitest"
        elif echo "$dev_deps" | grep -q "^jest$"; then
            DETECTED_TEST_FW="Jest"
        elif echo "$dev_deps" | grep -q "^mocha$"; then
            DETECTED_TEST_FW="Mocha"
        elif echo "$dev_deps" | grep -q "^ava$"; then
            DETECTED_TEST_FW="AVA"
        fi

        # Detect formatter/linter from devDependencies
        if echo "$dev_deps" | grep -q "^@biomejs/biome$"; then
            DETECTED_FORMATTER="Biome"
        elif echo "$dev_deps" | grep -q "^biome$"; then
            DETECTED_FORMATTER="Biome"
        elif echo "$dev_deps" | grep -q "^prettier$"; then
            if echo "$dev_deps" | grep -q "^eslint$"; then
                DETECTED_FORMATTER="ESLint + Prettier"
            else
                DETECTED_FORMATTER="Prettier"
            fi
        elif echo "$dev_deps" | grep -q "^eslint$"; then
            DETECTED_FORMATTER="ESLint"
        fi
    fi

    # Detect test location
    if [ -d "$project_dir/__tests__" ]; then
        DETECTED_TEST_LOC="__tests__/ directory"
    elif [ -d "$project_dir/tests" ]; then
        DETECTED_TEST_LOC="tests/ directory"
    elif [ -d "$project_dir/test" ]; then
        DETECTED_TEST_LOC="test/ directory"
    elif [ -d "$project_dir/src" ] && find "$project_dir/src" -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | head -1 | grep -q .; then
        DETECTED_TEST_LOC="co-located with source files"
    fi

    # Detect deployment platform from config files
    if [ -f "$project_dir/vercel.json" ] || [ -f "$project_dir/.vercel/project.json" ]; then
        DETECTED_DEPLOY="Vercel"
    elif [ -f "$project_dir/netlify.toml" ]; then
        DETECTED_DEPLOY="Netlify"
    elif [ -f "$project_dir/fly.toml" ]; then
        DETECTED_DEPLOY="Fly.io"
    elif [ -f "$project_dir/railway.json" ]; then
        DETECTED_DEPLOY="Railway"
    elif [ -f "$project_dir/render.yaml" ]; then
        DETECTED_DEPLOY="Render"
    elif [ -f "$project_dir/Dockerfile" ]; then
        DETECTED_DEPLOY="Docker"
    elif [ -d "$project_dir/.aws" ] || [ -f "$project_dir/serverless.yml" ]; then
        DETECTED_DEPLOY="AWS"
    fi

    # Detect CI/CD from config files
    if [ -d "$project_dir/.github/workflows" ]; then
        DETECTED_CICD="GitHub Actions"
    elif [ -f "$project_dir/.gitlab-ci.yml" ]; then
        DETECTED_CICD="GitLab CI"
    elif [ -f "$project_dir/.circleci/config.yml" ]; then
        DETECTED_CICD="CircleCI"
    elif [ -f "$project_dir/Jenkinsfile" ]; then
        DETECTED_CICD="Jenkins"
    elif [ -f "$project_dir/bitbucket-pipelines.yml" ]; then
        DETECTED_CICD="Bitbucket Pipelines"
    elif [ -f "$project_dir/azure-pipelines.yml" ]; then
        DETECTED_CICD="Azure Pipelines"
    fi

    # Detect config method
    if [ -f "$project_dir/.env.example" ] || [ -f "$project_dir/.env.sample" ] || [ -f "$project_dir/.env.template" ]; then
        DETECTED_CONFIG="environment variables (.env)"
    elif [ -f "$project_dir/config/default.json" ] || [ -f "$project_dir/config/default.js" ]; then
        DETECTED_CONFIG="config files (config/)"
    fi

    # Try to get description from README if not in package.json
    if [ "$DETECTED_DESC" = "A software project" ]; then
        local readme=""
        for f in README.md readme.md README.MD Readme.md README; do
            [ -f "$project_dir/$f" ] && readme="$project_dir/$f" && break
        done
        if [ -n "$readme" ]; then
            # Try to extract first paragraph after title
            local desc
            desc=$(awk '/^#[^#]/{found=1; next} found && /^[^#\[]/ && !/^$/{print; exit}' "$readme" 2>/dev/null | head -c 200)
            [ -n "$desc" ] && DETECTED_DESC="$desc"
        fi
    fi
}

setup_project_claude_md_existing() {
    local project_dir="$1"
    local claude_md="$2"

    echo ""
    echo "  This looks like an existing project. Analyzing codebase..."
    echo ""

    # Detect project info first
    detect_project_info "$project_dir"

    echo -e "  ${GREEN}✓${NC} Project analyzed. Confirm or adjust the detected values:"
    echo ""

    # Collect user preferences with auto-detected defaults
    echo -ne "  Project name [$DETECTED_NAME]: "
    read -r proj_name
    proj_name="${proj_name:-$DETECTED_NAME}"

    echo -ne "  Project description [$DETECTED_DESC]: "
    read -r proj_desc
    proj_desc="${proj_desc:-$DETECTED_DESC}"

    echo -ne "  Test framework [$DETECTED_TEST_FW]: "
    read -r test_fw
    test_fw="${test_fw:-$DETECTED_TEST_FW}"

    echo -ne "  Package manager [$DETECTED_PKG_MGR]: "
    read -r pkg_mgr
    pkg_mgr="${pkg_mgr:-$DETECTED_PKG_MGR}"

    echo -ne "  Formatter/linter [$DETECTED_FORMATTER]: "
    read -r formatter
    formatter="${formatter:-$DETECTED_FORMATTER}"

    echo -ne "  Test location [$DETECTED_TEST_LOC]: "
    read -r test_loc
    test_loc="${test_loc:-$DETECTED_TEST_LOC}"

    echo -ne "  Config method [$DETECTED_CONFIG]: "
    read -r config_method
    config_method="${config_method:-$DETECTED_CONFIG}"

    echo -ne "  Deployment platform [$DETECTED_DEPLOY]: "
    read -r deploy_platform
    deploy_platform="${deploy_platform:-$DETECTED_DEPLOY}"

    echo -ne "  CI/CD [$DETECTED_CICD]: "
    read -r cicd
    cicd="${cicd:-$DETECTED_CICD}"

    echo -ne "  Preferred language for Claude responses [Spanish]: "
    read -r preferred_lang
    preferred_lang="${preferred_lang:-Spanish}"

    echo -ne "  Preferred language for code/comments/docs [English]: "
    read -r code_lang
    code_lang="${code_lang:-English}"

    echo ""

    local auto_generated=false

    # Try to use 'claude /init' to auto-generate
    if command -v claude &>/dev/null; then
        echo -e "  Running 'claude /init' to generate CLAUDE.md..."
        echo -e "  ${YELLOW}(This may take a minute)${NC}"
        echo ""

        # Run claude /init in the project directory
        if (cd "$project_dir" && timeout 120 claude -p "/init" --dangerously-skip-permissions 2>/dev/null); then
            # Check if CLAUDE.md was created
            if [ -f "$claude_md" ] && [ -s "$claude_md" ]; then
                auto_generated=true
                echo -e "  ${GREEN}✓${NC} Auto-generated from project analysis"
            fi
        fi
    fi

    # If auto-generation failed, use template with detected values
    if [ "$auto_generated" = false ]; then
        echo -e "  ${YELLOW}!${NC} Could not auto-generate. Using template instead."
        local template="$REPO_DIR/plugins/core/templates/project-minimal.md.template"
        if [ -f "$template" ]; then
            sed \
                -e "s|{{PROJECT_NAME}}|$proj_name|g" \
                -e "s|{{PROJECT_DESCRIPTION}}|$proj_desc|g" \
                -e "s|{{TEST_FRAMEWORK}}|$test_fw|g" \
                -e "s|{{PACKAGE_MANAGER}}|$pkg_mgr|g" \
                -e "s|{{FORMATTER}}|$formatter|g" \
                -e "s|{{TEST_LOCATION}}|$test_loc|g" \
                -e "s|{{CONFIG_METHOD}}|$config_method|g" \
                -e "s|{{DEPLOYMENT_PLATFORM}}|$deploy_platform|g" \
                -e "s|{{CI_CD}}|$cicd|g" \
                -e "s|{{PREFERRED_LANG}}|$preferred_lang|g" \
                -e "s|{{CODE_LANG}}|$code_lang|g" \
                "$template" > "$claude_md"
        fi
    fi

    # Append user preferences section
    cat >> "$claude_md" << EOF

## User Preferences

- **Test Framework**: $test_fw
- **Package Manager**: $pkg_mgr
- **Formatter/Linter**: $formatter
- **Test Location**: $test_loc
- **Config Method**: $config_method
- **Deployment Platform**: $deploy_platform
- **CI/CD**: $cicd

## Language Preferences

- Claude responses: $preferred_lang
- Code, comments, JSDoc, docs: $code_lang
EOF

    # Append global rules if user-level doesn't have them
    local user_claude_md="$HOME/.claude/CLAUDE.md"
    if ! has_qazuor_global_rules "$user_claude_md"; then
        inject_global_rules "$claude_md" "$preferred_lang"
    fi

    echo -e "  ${GREEN}✓${NC} Generated $claude_md"
    echo ""
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
    local repo="${2:-}"
    local known_file="$HOME/.claude/plugins/known_marketplaces.json"
    [ -f "$known_file" ] || return 1

    # Check by marketplace name
    if jq -e --arg name "$name" '.[$name]' "$known_file" &>/dev/null; then
        return 0
    fi

    # Check by repo name (last part of repo path, e.g., "ralph-loop-setup" from "MarioGiancini/ralph-loop-setup")
    if [ -n "$repo" ]; then
        local repo_name="${repo##*/}"
        if jq -e --arg name "$repo_name" '.[$name]' "$known_file" &>/dev/null; then
            return 0
        fi
    fi

    # Check if directory exists in marketplaces folder
    local marketplaces_dir="$HOME/.claude/plugins/marketplaces"
    if [ -d "$marketplaces_dir/$name" ]; then
        return 0
    fi
    if [ -n "$repo" ]; then
        local repo_name="${repo##*/}"
        if [ -d "$marketplaces_dir/$repo_name" ]; then
            return 0
        fi
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Claude-mem watchdog setup
# ---------------------------------------------------------------------------
setup_claude_mem_watchdog() {
    local watchdog_src="$PLUGINS_DIR/core/scripts/claude-mem-watchdog.sh"
    local watchdog_dst="$HOME/.claude-mem/watchdog.sh"

    # Check if source exists
    if [ ! -f "$watchdog_src" ]; then
        echo -e "    ${YELLOW}~${NC} Watchdog script not found, skipping"
        return 0
    fi

    # Check if claude-mem directory exists
    if [ ! -d "$HOME/.claude-mem" ]; then
        echo -e "    ${YELLOW}~${NC} claude-mem not initialized yet, skipping watchdog"
        return 0
    fi

    # Copy watchdog script
    cp "$watchdog_src" "$watchdog_dst"
    chmod +x "$watchdog_dst"
    echo -e "    ${GREEN}✓${NC} Watchdog script installed"

    # Setup cron job (every 30 minutes)
    # Skip if crontab is not available (e.g., in CI environments)
    if ! command -v crontab &>/dev/null; then
        echo -e "    ${YELLOW}~${NC} crontab not available, skipping cron setup"
        return 0
    fi

    local cron_entry="*/30 * * * * $watchdog_dst"
    local current_cron
    current_cron=$(crontab -l 2>/dev/null || echo "")

    if echo "$current_cron" | grep -q "claude-mem.*watchdog"; then
        echo -e "    ${GREEN}✓${NC} Watchdog cron already configured"
    else
        # Add cron entry (may fail in restricted environments)
        if (echo "$current_cron"; echo "$cron_entry") | grep -v "^$" | crontab - 2>/dev/null; then
            echo -e "    ${GREEN}✓${NC} Watchdog cron configured (every 30 min)"
        else
            echo -e "    ${YELLOW}~${NC} Could not configure cron (restricted environment)"
        fi
    fi
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
    local missing_indices=()
    local total
    total=$(jq '.plugins | length' "$catalog")

    for i in $(seq 0 $((total - 1))); do
        local plugin_id name desc
        plugin_id=$(jq -r ".plugins[$i].pluginId" "$catalog")
        name=$(jq -r ".plugins[$i].name" "$catalog")
        desc=$(jq -r ".plugins[$i].description" "$catalog")

        if is_plugin_installed "$plugin_id"; then
            echo -e "  ${GREEN}✓${NC} $name -- already installed"
        else
            missing_indices+=("$i")
            echo -e "  ${YELLOW}○${NC} $name -- $desc"
        fi
    done

    [ ${#missing_indices[@]} -eq 0 ] && {
        echo -e "\n${GREEN}All recommended plugins are already installed!${NC}"
        return 0
    }

    echo ""
    echo -e "  ${BLUE}Note:${NC} External plugins are always installed at user level"
    echo -e "        (available in all projects)."
    echo ""

    # Per-plugin selection (always user scope)
    for idx in "${missing_indices[@]}"; do
        local name marketplace repo plugin_id desc
        name=$(jq -r ".plugins[$idx].name" "$catalog")
        marketplace=$(jq -r ".plugins[$idx].marketplace" "$catalog")
        repo=$(jq -r ".plugins[$idx].repo" "$catalog")
        plugin_id=$(jq -r ".plugins[$idx].pluginId" "$catalog")
        desc=$(jq -r ".plugins[$idx].description" "$catalog")

        echo -ne "  Install ${CYAN}$name${NC} ($desc)? [Y/n]: "
        read -r answer
        [[ "$answer" =~ ^[Nn] ]] && continue

        # Add marketplace if not present
        if ! is_marketplace_added "$marketplace" "$repo"; then
            echo -e "    Adding marketplace $repo..."
            if claude plugin marketplace add "$repo" 2>&1; then
                echo -e "    ${GREEN}✓${NC} Marketplace added"
            else
                echo -e "    ${RED}✗${NC} Failed to add marketplace -- skipping $name"
                continue
            fi
        fi

        # Install at user level
        echo -e "    Installing $name..."
        if claude plugin install "$plugin_id" --scope user 2>&1; then
            echo -e "    ${GREEN}✓${NC} $name installed"

            # Setup watchdog for claude-mem
            if [[ "$plugin_id" == *"claude-mem"* ]]; then
                echo -e "    Setting up claude-mem watchdog..."
                setup_claude_mem_watchdog
            fi
        else
            echo -e "    ${RED}✗${NC} Failed to install $name"
        fi
        echo ""
    done
}

# ---------------------------------------------------------------------------
# Interactive wizard (runs when no arguments are provided)
# ---------------------------------------------------------------------------
interactive_wizard() {
    echo -e "${CYAN}No arguments provided. Starting interactive setup...${NC}"
    echo ""

    # Q1: Install mode (default: project-level)
    echo -e "  ${BLUE}1.${NC} Installation mode?"
    echo "     [P] Project-level (current directory) - recommended"
    echo "     [U] User-level (all projects)"
    echo -ne "     Choose [P/u]: "
    read -r mode_choice
    mode_choice="${mode_choice:-P}"
    if [[ "$mode_choice" =~ ^[Uu] ]]; then
        PROJECT_MODE=false
    else
        PROJECT_MODE=true
        PROJECT_DIR="$(pwd)"
    fi

    # Q2: Profile (dynamic from profiles/ directory)
    echo ""
    echo -e "  ${BLUE}2.${NC} Profile?"
    local profile_list=()
    local i=1
    for pf in "$SCRIPT_DIR/profiles"/*.json; do
        [ -f "$pf" ] || continue
        local pname pplugins
        pname=$(jq -r '.name // "unknown"' "$pf")
        pplugins=$(jq -r '.plugins | join(", ")' "$pf")
        profile_list+=("$pname")
        echo "     [$i] $pname -- $pplugins"
        i=$((i + 1))
    done
    echo -ne "     Choose [1-${#profile_list[@]}]: "
    read -r profile_choice
    profile_choice="${profile_choice:-1}"
    if [[ "$profile_choice" =~ ^[0-9]+$ ]] && \
       [ "$profile_choice" -ge 1 ] && \
       [ "$profile_choice" -le "${#profile_list[@]}" ]; then
        PROFILE="${profile_list[$((profile_choice - 1))]}"
    else
        PROFILE="${profile_list[0]}"
    fi

    # Q3: MCP setup
    echo ""
    echo -e "  ${BLUE}3.${NC} Configure MCP API keys after install?"
    echo -ne "     [y/N]: "
    read -r mcp_choice
    if [[ "$mcp_choice" =~ ^[Yy] ]]; then
        SETUP_MCP=true
    fi

    echo ""
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
        --yes|-y)
            YES_MODE=true
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

# If no profile/enable flags provided, run interactive wizard (unless dry-run or piped)
if [ -z "$PROFILE" ] && [ ${#ENABLE_PLUGINS[@]} -eq 0 ] && \
   [ "$DRY_RUN" = false ] && [ -t 0 ]; then
    interactive_wizard
    # Validate project dir if wizard set project mode
    if [ "$PROJECT_MODE" = true ] && [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}ERROR: Project directory does not exist: $PROJECT_DIR${NC}"
        exit 1
    fi
    [ "$PROJECT_MODE" = true ] && PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
fi

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
    # Fallback: install all plugins (dry-run, piped, or no wizard ran)
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
    # Show CLAUDE.md status
    echo ""
    if [ "$PROJECT_MODE" = true ]; then
        proj_claude_md="$PROJECT_DIR/.claude/CLAUDE.md"
        if [ -f "$proj_claude_md" ] && [ -s "$proj_claude_md" ] && \
           ! grep -q "Describe your project here\.\.\." "$proj_claude_md" 2>/dev/null; then
            echo -e "  ${CYAN}CLAUDE.md:${NC} $proj_claude_md already exists — would skip"
        else
            echo -e "  ${CYAN}Would also offer to generate:${NC}"
            echo "    $proj_claude_md (from project-generic.md.template)"
            if has_qazuor_global_rules "$HOME/.claude/CLAUDE.md"; then
                echo "    (global rules omitted — already in user-level)"
            else
                echo "    (global rules included — not found in user-level)"
            fi
        fi
    else
        claude_md="$HOME/.claude/CLAUDE.md"
        if [ ! -f "$claude_md" ] || [ ! -s "$claude_md" ] || \
           grep -q "Describe your project here\.\.\." "$claude_md" 2>/dev/null; then
            echo -e "  ${CYAN}Would also offer to generate:${NC}"
            echo "    ~/.claude/CLAUDE.md (from global.md.template)"
        elif has_qazuor_global_rules "$claude_md"; then
            echo -e "  ${CYAN}CLAUDE.md:${NC} Would offer to update global rules to latest version"
        else
            echo -e "  ${CYAN}CLAUDE.md:${NC} Has custom content — would offer Skip/Overwrite/Merge"
        fi
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

    # Build index of components already available at user level
    build_user_level_component_index
    total_user_components=$(( ${#USER_AGENTS[@]} + ${#USER_COMMANDS[@]} + ${#USER_SKILLS[@]} + ${#USER_DOCS[@]} + ${#USER_TEMPLATES[@]} ))
    if [ "$total_user_components" -gt 0 ]; then
        echo -e "${BLUE}Note:${NC} Found $total_user_components components at user level. Duplicates will be skipped."
        echo ""
    fi

    for plugin_name in "${PLUGINS_TO_INSTALL[@]}"; do
        plugin_dir="$PLUGINS_DIR/$plugin_name"
        if [ -d "$plugin_dir" ]; then
            # Pass true to skip plugins already enabled at user level
            if install_plugin_project "$plugin_dir" "$CLAUDE_DIR" true; then
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

    # Merge MCP servers into .mcp.json at project root (skip user-level dupes)
    for plugin_name in "${INSTALLED[@]}"; do
        plugin_dir="$PLUGINS_DIR/$plugin_name"
        if [ -f "$plugin_dir/.mcp.json" ]; then
            echo -e "${CYAN}Merging MCP servers...${NC}"
            # Build skip list from user-level config to avoid duplicates
            skip_keys="[]"
            if [ -f "$HOME/.claude.json" ]; then
                skip_keys=$(jq '[.mcpServers // {} | keys[]]' "$HOME/.claude.json") || skip_keys="[]"
            fi
            merge_mcp "$plugin_dir" "$PROJECT_DIR" "$skip_keys"
            echo ""
            break  # Only one plugin has .mcp.json
        fi
    done

    # Setup project CLAUDE.md
    setup_project_claude_md "$PROJECT_DIR"

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

    # Setup CLAUDE.md if empty/placeholder
    setup_claude_md
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

# Setup claude-mem watchdog if already installed (for existing users)
if [ "$DRY_RUN" = false ] && [ -d "$HOME/.claude-mem" ]; then
    if [ ! -f "$HOME/.claude-mem/watchdog.sh" ] || \
       ! crontab -l 2>/dev/null | grep -q "claude-mem.*watchdog"; then
        echo -e "${CYAN}Claude-mem Watchdog${NC}"
        setup_claude_mem_watchdog
        echo ""
    fi
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
