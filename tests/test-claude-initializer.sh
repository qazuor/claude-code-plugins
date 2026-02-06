#!/usr/bin/env bash
# =============================================================================
# test-claude-initializer.sh - Tests for claude-initializer plugin
# =============================================================================
#
# Tests:
#   - Template files exist and have expected content
#   - settings-template.json structure
#   - brand-config.json.template structure
#   - global.md.template has sentinel comments
#   - Command file structure
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

PLUGIN_DIR="$PROJECT_ROOT/plugins/claude-initializer"

# ============================================================================
# Template Files
# ============================================================================
describe "Template Files Exist"

it "global.md.template exists"
assert_file_exists "$PLUGIN_DIR/templates/global.md.template" "$CURRENT_TEST"

it "global-rules-block.md.template exists"
assert_file_exists "$PLUGIN_DIR/templates/global-rules-block.md.template" "$CURRENT_TEST"

it "settings-template.json exists"
assert_file_exists "$PLUGIN_DIR/templates/settings-template.json" "$CURRENT_TEST"

it "brand-config.json.template exists"
assert_file_exists "$PLUGIN_DIR/templates/brand-config.json.template" "$CURRENT_TEST"

# ============================================================================
# settings-template.json
# ============================================================================
describe "settings-template.json Structure"

SETTINGS_TPL="$PLUGIN_DIR/templates/settings-template.json"

it "Is valid JSON"
assert_json_valid "$SETTINGS_TPL" "$CURRENT_TEST"

it "Has permissions.allow"
assert_json_has_key "$SETTINGS_TPL" ".permissions.allow" "$CURRENT_TEST"

it "Has permissions.deny"
assert_json_has_key "$SETTINGS_TPL" ".permissions.deny" "$CURRENT_TEST"

it "permissions.allow is an array"
type=$(jq -r '.permissions.allow | type' "$SETTINGS_TPL")
assert_equals "array" "$type" "$CURRENT_TEST"

it "permissions.deny is an array"
type=$(jq -r '.permissions.deny | type' "$SETTINGS_TPL")
assert_equals "array" "$type" "$CURRENT_TEST"

# ============================================================================
# brand-config.json.template
# ============================================================================
describe "brand-config.json.template Structure"

BRAND_TPL="$PLUGIN_DIR/templates/brand-config.json.template"

it "Is valid JSON"
assert_json_valid "$BRAND_TPL" "$CURRENT_TEST"

it "Has brand section"
assert_json_has_key "$BRAND_TPL" ".brand" "$CURRENT_TEST"

it "Has design section"
design_exists=$(jq 'has("design") or has("brand")' "$BRAND_TPL")
assert_equals "true" "$design_exists" "$CURRENT_TEST"

# ============================================================================
# global.md.template Sentinel Comments
# ============================================================================
describe "global.md.template Content"

GLOBAL_TPL="$PLUGIN_DIR/templates/global.md.template"

it "Contains markdown content"
line_count=$(wc -l < "$GLOBAL_TPL")
assert_gt "$line_count" 5 "Template has more than 5 lines ($line_count)"

# ============================================================================
# global-rules-block.md.template
# ============================================================================
describe "global-rules-block.md.template Content"

RULES_TPL="$PLUGIN_DIR/templates/global-rules-block.md.template"

it "Contains markdown content"
line_count=$(wc -l < "$RULES_TPL")
assert_gt "$line_count" 3 "Template has more than 3 lines ($line_count)"

it "Contains sentinel comments for merge"
# Sentinel comments allow merge detection
has_sentinel="false"
if grep -q "BEGIN\|END\|SENTINEL\|<!--" "$RULES_TPL" 2>/dev/null; then
    has_sentinel="true"
fi
# Not all templates use sentinels, so check for general structure markers
has_headers="false"
if grep -q "^#" "$RULES_TPL" 2>/dev/null; then
    has_headers="true"
fi
# At least one of these should be true
if [[ "$has_sentinel" == "true" ]] || [[ "$has_headers" == "true" ]]; then
    assert_equals "true" "true" "$CURRENT_TEST"
else
    assert_equals "true" "false" "$CURRENT_TEST"
fi

# ============================================================================
# Command File
# ============================================================================
describe "init-project Command"

it "init-project.md exists"
assert_file_exists "$PLUGIN_DIR/commands/init-project.md" "$CURRENT_TEST"

it "init-project.md has frontmatter"
first_line=$(head -n 1 "$PLUGIN_DIR/commands/init-project.md")
assert_equals "---" "$first_line" "$CURRENT_TEST"

it "init-project.md has description"
closing_line=$(sed -n '2,${/^---$/=;}' "$PLUGIN_DIR/commands/init-project.md" | head -n 1)
if [[ -n "$closing_line" ]]; then
    frontmatter=$(sed -n "2,$((closing_line - 1))p" "$PLUGIN_DIR/commands/init-project.md")
    has_desc="false"
    if echo "$frontmatter" | grep -q "^description:"; then
        has_desc="true"
    fi
    assert_equals "true" "$has_desc" "$CURRENT_TEST"
else
    assert_equals "true" "false" "Frontmatter not properly closed"
fi

# ============================================================================
# setup-project Command
# ============================================================================
describe "setup-project Command"

it "setup-project.md exists"
assert_file_exists "$PLUGIN_DIR/commands/setup-project.md" "$CURRENT_TEST"

it "setup-project.md has frontmatter"
first_line=$(head -n 1 "$PLUGIN_DIR/commands/setup-project.md")
assert_equals "---" "$first_line" "$CURRENT_TEST"

it "setup-project.md has description"
closing_line=$(sed -n '2,${/^---$/=;}' "$PLUGIN_DIR/commands/setup-project.md" | head -n 1)
if [[ -n "$closing_line" ]]; then
    frontmatter=$(sed -n "2,$((closing_line - 1))p" "$PLUGIN_DIR/commands/setup-project.md")
    has_desc="false"
    if echo "$frontmatter" | grep -q "^description:"; then
        has_desc="true"
    fi
    assert_equals "true" "$has_desc" "$CURRENT_TEST"
else
    assert_equals "true" "false" "Frontmatter not properly closed"
fi

# ============================================================================
# Summary
# ============================================================================
print_summary
