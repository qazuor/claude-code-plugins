#!/usr/bin/env bash
# =============================================================================
# test-structure.sh - Structural validation tests
# =============================================================================
#
# Validates:
#   - All JSON files are valid
#   - All plugin.json have required fields
#   - Plugin names match directory names
#   - All scripts are executable
#   - Naming conventions (kebab-case)
#   - No broken references to deleted paths
#   - base-permissions.json structure
#   - JSON schemas are well-formed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

EXPECTED_PLUGINS=("claude-initializer" "knowledge-sync" "mcp-servers" "notifications" "permission-sync" "session-tools" "task-master")

# ============================================================================
# JSON Validation
# ============================================================================
describe "JSON Validation"

# plugin.json manifests
for plugin in "${EXPECTED_PLUGINS[@]}"; do
    manifest="$PROJECT_ROOT/plugins/$plugin/.claude-plugin/plugin.json"
    it "plugin.json is valid JSON: $plugin"
    assert_json_valid "$manifest" "$CURRENT_TEST"
done

# hooks.json files
while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    name=$(echo "$f" | sed "s|$PROJECT_ROOT/||")
    it "hooks.json is valid JSON: $name"
    assert_json_valid "$f" "$CURRENT_TEST"
done < <(find "$PROJECT_ROOT/plugins" -name "hooks.json" -path "*/hooks/*" -type f 2>/dev/null)

# Other JSON files
while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    name=$(echo "$f" | sed "s|$PROJECT_ROOT/||")
    it "Valid JSON: $name"
    assert_json_valid "$f" "$CURRENT_TEST"
done < <(find "$PROJECT_ROOT/plugins" -name "*.json" -not -path "*/hooks/*" -not -path "*/.claude-plugin/*" -type f 2>/dev/null)

# package.json
it "package.json is valid JSON"
assert_json_valid "$PROJECT_ROOT/package.json" "$CURRENT_TEST"

# ============================================================================
# Plugin Structure
# ============================================================================
describe "Plugin Structure"

# All expected plugins exist
for plugin in "${EXPECTED_PLUGINS[@]}"; do
    it "Plugin directory exists: $plugin"
    assert_dir_exists "$PROJECT_ROOT/plugins/$plugin" "$CURRENT_TEST"
done

# All plugins have plugin.json
for plugin in "${EXPECTED_PLUGINS[@]}"; do
    it "Plugin has plugin.json: $plugin"
    assert_file_exists "$PROJECT_ROOT/plugins/$plugin/.claude-plugin/plugin.json" "$CURRENT_TEST"
done

# ============================================================================
# Plugin Manifest Fields
# ============================================================================
describe "Plugin Manifest Fields"

for plugin in "${EXPECTED_PLUGINS[@]}"; do
    manifest="$PROJECT_ROOT/plugins/$plugin/.claude-plugin/plugin.json"
    [[ -f "$manifest" ]] || continue

    it "plugin.json has 'name': $plugin"
    assert_json_has_key "$manifest" ".name" "$CURRENT_TEST"

    it "plugin.json has 'version': $plugin"
    assert_json_has_key "$manifest" ".version" "$CURRENT_TEST"

    it "plugin.json has 'description': $plugin"
    assert_json_has_key "$manifest" ".description" "$CURRENT_TEST"

    # Name matches directory
    it "plugin.json name matches directory: $plugin"
    manifest_name=$(jq -r '.name' "$manifest")
    assert_equals "$plugin" "$manifest_name" "$CURRENT_TEST"
done

# ============================================================================
# Script Executability
# ============================================================================
describe "Script Executability"

while IFS= read -r f; do
    name=$(echo "$f" | sed "s|$PROJECT_ROOT/||")
    it "Script is executable: $name"
    assert_executable "$f" "$CURRENT_TEST"
done < <(find "$PROJECT_ROOT/plugins" -name "*.sh" -type f 2>/dev/null)

# ============================================================================
# Command Format
# ============================================================================
describe "Command Format (YAML Frontmatter)"

while IFS= read -r cmd_file; do
    [[ -f "$cmd_file" ]] || continue
    cmd_name=$(basename "$cmd_file" .md)
    plugin_name=$(echo "$cmd_file" | sed "s|$PROJECT_ROOT/plugins/||" | cut -d/ -f1)

    # Check for frontmatter
    it "Command has frontmatter: $plugin_name/$cmd_name"
    first_line=$(head -n 1 "$cmd_file")
    assert_equals "---" "$first_line" "$CURRENT_TEST"

    # Check for closing frontmatter
    it "Command has closing frontmatter: $plugin_name/$cmd_name"
    closing_count=$(sed -n '2,${/^---$/=;}' "$cmd_file" | head -n 1)
    assert_not_equals "" "${closing_count:-}" "$CURRENT_TEST"

    # Check for description field
    if [[ -n "${closing_count:-}" ]]; then
        frontmatter=$(sed -n "2,$((closing_count - 1))p" "$cmd_file")
        it "Command has description: $plugin_name/$cmd_name"
        has_desc="false"
        if echo "$frontmatter" | grep -q "^description:"; then
            has_desc="true"
        fi
        assert_equals "true" "$has_desc" "$CURRENT_TEST"
    fi
done < <(find "$PROJECT_ROOT/plugins" -path "*/commands/*.md" -type f 2>/dev/null)

# ============================================================================
# Skill Format
# ============================================================================
describe "Skill Format"

while IFS= read -r dir; do
    [[ -d "$dir" ]] || continue
    skill_name=$(basename "$dir")
    plugin_name=$(echo "$dir" | sed "s|$PROJECT_ROOT/plugins/||" | cut -d/ -f1)

    it "Skill has SKILL.md: $plugin_name/$skill_name"
    assert_file_exists "$dir/SKILL.md" "$CURRENT_TEST"

    if [[ -f "$dir/SKILL.md" ]]; then
        it "Skill has frontmatter: $plugin_name/$skill_name"
        first_line=$(head -n 1 "$dir/SKILL.md")
        assert_equals "---" "$first_line" "$CURRENT_TEST"
    fi
done < <(find "$PROJECT_ROOT/plugins" -path "*/skills/*" -maxdepth 4 -mindepth 4 -type d 2>/dev/null)

# ============================================================================
# Agent Format
# ============================================================================
describe "Agent Format"

while IFS= read -r agent_file; do
    [[ -f "$agent_file" ]] || continue
    agent_name=$(basename "$agent_file" .md)
    plugin_name=$(echo "$agent_file" | sed "s|$PROJECT_ROOT/plugins/||" | cut -d/ -f1)

    it "Agent has frontmatter: $plugin_name/$agent_name"
    first_line=$(head -n 1 "$agent_file")
    assert_equals "---" "$first_line" "$CURRENT_TEST"

    # Check for required fields
    closing_count=$(sed -n '2,${/^---$/=;}' "$agent_file" | head -n 1)
    if [[ -n "${closing_count:-}" ]]; then
        frontmatter=$(sed -n "2,$((closing_count - 1))p" "$agent_file")

        it "Agent has name field: $plugin_name/$agent_name"
        has_name="false"
        if echo "$frontmatter" | grep -q "^name:"; then
            has_name="true"
        fi
        assert_equals "true" "$has_name" "$CURRENT_TEST"

        it "Agent has description field: $plugin_name/$agent_name"
        has_desc="false"
        if echo "$frontmatter" | grep -q "^description:"; then
            has_desc="true"
        fi
        assert_equals "true" "$has_desc" "$CURRENT_TEST"
    fi
done < <(find "$PROJECT_ROOT/plugins" -path "*/agents/*.md" -type f 2>/dev/null)

# ============================================================================
# Naming Conventions (kebab-case)
# ============================================================================
describe "Naming Conventions"

# Command file names
while IFS= read -r cmd_file; do
    [[ -f "$cmd_file" ]] || continue
    cmd_name=$(basename "$cmd_file" .md)
    it "Command follows kebab-case: $cmd_name"
    is_kebab="false"
    if echo "$cmd_name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
        is_kebab="true"
    fi
    assert_equals "true" "$is_kebab" "$CURRENT_TEST"
done < <(find "$PROJECT_ROOT/plugins" -path "*/commands/*.md" -type f 2>/dev/null)

# Skill directory names
while IFS= read -r dir; do
    [[ -d "$dir" ]] || continue
    skill_name=$(basename "$dir")
    it "Skill dir follows kebab-case: $skill_name"
    is_kebab="false"
    if echo "$skill_name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
        is_kebab="true"
    fi
    assert_equals "true" "$is_kebab" "$CURRENT_TEST"
done < <(find "$PROJECT_ROOT/plugins" -path "*/skills/*" -maxdepth 4 -mindepth 4 -type d 2>/dev/null)

# Plugin directory names
for plugin in "${EXPECTED_PLUGINS[@]}"; do
    it "Plugin dir follows kebab-case: $plugin"
    is_kebab="false"
    if echo "$plugin" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
        is_kebab="true"
    fi
    assert_equals "true" "$is_kebab" "$CURRENT_TEST"
done

# ============================================================================
# No Broken References
# ============================================================================
describe "No Broken References to Deleted Paths"

# Check for references to old deleted directories
DELETED_PATHS=("plugins/core" "plugins/frameworks-frontend" "plugins/frameworks-backend" "plugins/frameworks-shared" "installer/")

while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    name=$(echo "$f" | sed "s|$PROJECT_ROOT/||")

    # Skip CHANGELOG.md (has intentional historical references)
    if [[ "$name" == "CHANGELOG.md" ]]; then
        continue
    fi

    for deleted in "${DELETED_PATHS[@]}"; do
        it "No reference to '$deleted' in: $name"
        has_ref="false"
        if grep -q "$deleted" "$f" 2>/dev/null; then
            has_ref="true"
        fi
        assert_equals "false" "$has_ref" "$CURRENT_TEST"
    done
done < <(find "$PROJECT_ROOT" -name "*.sh" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" | grep -v node_modules | grep -v ".git/" | grep -v "CHANGELOG.md" | grep -v "tests/" 2>/dev/null)

# ============================================================================
# base-permissions.json Structure
# ============================================================================
describe "base-permissions.json Structure"

BASE_PERMS="$PROJECT_ROOT/plugins/permission-sync/templates/base-permissions.json"

it "base-permissions.json exists"
assert_file_exists "$BASE_PERMS" "$CURRENT_TEST"

it "Has permissions.allow array"
assert_json_has_key "$BASE_PERMS" ".permissions.allow" "$CURRENT_TEST"

it "Has permissions.ask array"
assert_json_has_key "$BASE_PERMS" ".permissions.ask" "$CURRENT_TEST"

it "Has permissions.deny array"
assert_json_has_key "$BASE_PERMS" ".permissions.deny" "$CURRENT_TEST"

it "permissions.allow is non-empty"
allow_count=$(jq '.permissions.allow | length' "$BASE_PERMS")
assert_gt "$allow_count" 0 "$CURRENT_TEST (count: $allow_count)"

it "permissions.allow is sorted"
sorted=$(jq -r '.permissions.allow | . == sort' "$BASE_PERMS")
assert_equals "true" "$sorted" "$CURRENT_TEST"

it "permissions.allow has no duplicates"
total=$(jq '.permissions.allow | length' "$BASE_PERMS")
unique=$(jq '.permissions.allow | unique | length' "$BASE_PERMS")
assert_equals "$total" "$unique" "$CURRENT_TEST"

# ============================================================================
# JSON Schemas
# ============================================================================
describe "JSON Schemas Well-Formed"

while IFS= read -r schema_file; do
    [[ -f "$schema_file" ]] || continue
    name=$(echo "$schema_file" | sed "s|$PROJECT_ROOT/||")

    it "Schema is valid JSON: $name"
    assert_json_valid "$schema_file" "$CURRENT_TEST"

    # Check for $schema or type field
    has_schema=$(jq 'has("$schema") or has("type") or has("properties")' "$schema_file" 2>/dev/null || echo "false")
    it "Schema has type/schema/properties: $name"
    assert_equals "true" "$has_schema" "$CURRENT_TEST"
done < <(find "$PROJECT_ROOT/plugins" -name "*schema*.json" -type f 2>/dev/null)

# ============================================================================
# package.json
# ============================================================================
describe "package.json"

it "Has name field"
assert_json_has_key "$PROJECT_ROOT/package.json" ".name" "$CURRENT_TEST"

it "Version is 2.0.0"
version=$(jq -r '.version' "$PROJECT_ROOT/package.json")
assert_equals "2.0.0" "$version" "$CURRENT_TEST"

# ============================================================================
# Summary
# ============================================================================
print_summary
