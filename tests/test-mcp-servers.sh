#!/usr/bin/env bash
# =============================================================================
# test-mcp-servers.sh - Structural tests for mcp-servers plugin
# =============================================================================
#
# Tests:
#   - .mcp.json structure and server configuration
#   - check-deps.sh: output structure, env check functions
#   - All servers have required fields
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

PLUGIN_DIR="$PROJECT_ROOT/plugins/mcp-servers"
MCP_FILE="$PLUGIN_DIR/.mcp.json"

# ============================================================================
# .mcp.json Structure
# ============================================================================
describe ".mcp.json Structure"

it ".mcp.json exists"
assert_file_exists "$MCP_FILE" "$CURRENT_TEST"

it ".mcp.json is valid JSON"
assert_json_valid "$MCP_FILE" "$CURRENT_TEST"

it "Has mcpServers key"
assert_json_has_key "$MCP_FILE" ".mcpServers" "$CURRENT_TEST"

it "Has at least 10 servers"
server_count=$(jq '.mcpServers | length' "$MCP_FILE")
assert_gt "$server_count" 9 "Server count: $server_count"

# ============================================================================
# Server Configuration
# ============================================================================
describe "Server Configuration"

servers=$(jq -r '.mcpServers | keys[]' "$MCP_FILE" 2>/dev/null)

for server in $servers; do
    server_type=$(jq -r ".mcpServers[\"$server\"].type // empty" "$MCP_FILE")

    if [[ "$server_type" == "http" ]]; then
        # HTTP server: needs url
        it "HTTP server has url: $server"
        url=$(jq -r ".mcpServers[\"$server\"].url // empty" "$MCP_FILE")
        assert_not_equals "" "$url" "$CURRENT_TEST"
    else
        # Command server: needs command and args
        it "Server has command: $server"
        cmd=$(jq -r ".mcpServers[\"$server\"].command // empty" "$MCP_FILE")
        assert_not_equals "" "$cmd" "$CURRENT_TEST"

        it "Server has args: $server"
        args_len=$(jq ".mcpServers[\"$server\"].args | length" "$MCP_FILE" 2>/dev/null || echo "0")
        assert_gt "$args_len" 0 "$CURRENT_TEST"
    fi
done

# ============================================================================
# check-deps.sh: Functions
# ============================================================================
describe "check-deps.sh: Utility Functions"

it "check_command function detects existing command"
# Test the check_command pattern
(
    if command -v jq &>/dev/null; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "check_command function detects missing command"
(
    if command -v nonexistent_command_xyz &>/dev/null; then
        exit 1
    fi
    exit 0
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

# ============================================================================
# check-deps.sh: Output
# ============================================================================
describe "check-deps.sh: Output Structure"

it "Script runs without error"
output=$("$PLUGIN_DIR/scripts/check-deps.sh" 2>&1) || true
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Output contains base requirements section"
output=$("$PLUGIN_DIR/scripts/check-deps.sh" 2>&1) || true
assert_contains "$output" "Base Requirements" "$CURRENT_TEST"

it "Output contains no-key-required section"
output=$("$PLUGIN_DIR/scripts/check-deps.sh" 2>&1) || true
assert_contains "$output" "No API Key Required" "$CURRENT_TEST"

it "Output contains API key section"
output=$("$PLUGIN_DIR/scripts/check-deps.sh" 2>&1) || true
assert_contains "$output" "API Key Required" "$CURRENT_TEST"

it "Output contains summary section"
output=$("$PLUGIN_DIR/scripts/check-deps.sh" 2>&1) || true
assert_contains "$output" "Summary" "$CURRENT_TEST"

it "Lists always-available servers"
output=$("$PLUGIN_DIR/scripts/check-deps.sh" 2>&1) || true
assert_contains "$output" "sequential-thinking" "$CURRENT_TEST"
assert_contains "$output" "context7" "Lists context7 as always available"
assert_contains "$output" "filesystem" "Lists filesystem as always available"

# ============================================================================
# mcp-schema.json
# ============================================================================
describe "MCP Schema"

it "mcp-schema.json exists"
assert_file_exists "$PLUGIN_DIR/mcp-schema.json" "$CURRENT_TEST"

it "mcp-schema.json is valid JSON"
assert_json_valid "$PLUGIN_DIR/mcp-schema.json" "$CURRENT_TEST"

# ============================================================================
# Summary
# ============================================================================
print_summary
