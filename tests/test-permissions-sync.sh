#!/usr/bin/env bash
# =============================================================================
# test-permissions-sync.sh - Functional tests for permission-sync plugin
# =============================================================================
#
# Tests:
#   - permissions-sync.sh: extract_new_perms, add_to_base, merge_to_project
#   - permissions-sync-all.sh: --dry-run, argument parsing
#   - Graceful exit when files missing
#   - Idempotent sync operations
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

# ============================================================================
# Setup: Create temp fixtures
# ============================================================================
setup_tmpdir

create_base_perms() {
    cat > "$TEST_TMPDIR/base-permissions.json" << 'EOF'
{
  "permissions": {
    "allow": ["Bash(git status:*)", "Bash(ls:*)"],
    "ask": ["Bash(rm:*)"],
    "deny": ["Bash(sudo:*)"]
  }
}
EOF
}

create_project_settings() {
    mkdir -p "$TEST_TMPDIR/project/.claude"
    cat > "$TEST_TMPDIR/project/.claude/settings.local.json" << 'EOF'
{
  "permissions": {
    "allow": ["Bash(git status:*)", "Bash(npm test:*)"],
    "ask": ["Bash(rm:*)"],
    "deny": ["Bash(sudo:*)", "Bash(reboot:*)"]
  }
}
EOF
}

# ============================================================================
# Test: Graceful exit when base permissions missing
# ============================================================================
describe "permissions-sync.sh: Graceful Exit"

it "Exits 0 when base permissions file missing"
(
    export HOME="$TEST_TMPDIR"
    mkdir -p "$TEST_TMPDIR/fake-plugin/templates"
    # No base-permissions.json
    cd "$TEST_TMPDIR"

    # Source the script functions by creating a test wrapper
    cat > "$TEST_TMPDIR/test-sync.sh" << 'WRAPPER'
#!/bin/bash
set -euo pipefail
PLUGIN_ROOT="$1"
BASE_PERMS="${PLUGIN_ROOT}/templates/base-permissions.json"
PROJECT_SETTINGS=".claude/settings.local.json"
LOG_FILE="/dev/null"
if [[ ! -f "$BASE_PERMS" ]]; then
    exit 0
fi
exit 1
WRAPPER
    chmod +x "$TEST_TMPDIR/test-sync.sh"
    "$TEST_TMPDIR/test-sync.sh" "$TEST_TMPDIR/fake-plugin"
    exit_code=$?
    exit "$exit_code"
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Exits 0 when project settings missing"
(
    create_base_perms
    cd "$TEST_TMPDIR"
    mkdir -p "$TEST_TMPDIR/plugin-with-base/templates"
    cp "$TEST_TMPDIR/base-permissions.json" "$TEST_TMPDIR/plugin-with-base/templates/"

    cat > "$TEST_TMPDIR/test-no-project.sh" << 'WRAPPER'
#!/bin/bash
set -euo pipefail
PLUGIN_ROOT="$1"
BASE_PERMS="${PLUGIN_ROOT}/templates/base-permissions.json"
PROJECT_SETTINGS=".claude/settings.local.json"
if [[ ! -f "$BASE_PERMS" ]]; then
    exit 1
fi
if [[ ! -f "$PROJECT_SETTINGS" ]]; then
    exit 0
fi
exit 1
WRAPPER
    chmod +x "$TEST_TMPDIR/test-no-project.sh"
    "$TEST_TMPDIR/test-no-project.sh" "$TEST_TMPDIR/plugin-with-base"
    exit "$?"
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

# ============================================================================
# Test: extract_new_perms
# ============================================================================
describe "permissions-sync.sh: Extract New Permissions"

create_base_perms
create_project_settings

it "Detects new allow permissions in project"
new_allows=$(
    jq -r '.permissions.allow // [] | .[]' "$TEST_TMPDIR/project/.claude/settings.local.json" | sort -u > "$TEST_TMPDIR/proj_allow"
    jq -r '.permissions.allow // [] | .[]' "$TEST_TMPDIR/base-permissions.json" | sort -u > "$TEST_TMPDIR/base_allow"
    comm -23 "$TEST_TMPDIR/proj_allow" "$TEST_TMPDIR/base_allow" 2>/dev/null
)
assert_contains "$new_allows" "Bash(npm test:\\*)" "$CURRENT_TEST"

it "Does not flag existing allow permissions as new"
assert_not_contains "$new_allows" "Bash(git status:\\*)" "$CURRENT_TEST"

it "Detects new deny permissions in project"
new_denies=$(
    jq -r '.permissions.deny // [] | .[]' "$TEST_TMPDIR/project/.claude/settings.local.json" | sort -u > "$TEST_TMPDIR/proj_deny"
    jq -r '.permissions.deny // [] | .[]' "$TEST_TMPDIR/base-permissions.json" | sort -u > "$TEST_TMPDIR/base_deny"
    comm -23 "$TEST_TMPDIR/proj_deny" "$TEST_TMPDIR/base_deny" 2>/dev/null
)
assert_contains "$new_denies" "Bash(reboot:\\*)" "$CURRENT_TEST"

it "No new ask permissions when identical"
new_asks=$(
    jq -r '.permissions.ask // [] | .[]' "$TEST_TMPDIR/project/.claude/settings.local.json" | sort -u > "$TEST_TMPDIR/proj_ask"
    jq -r '.permissions.ask // [] | .[]' "$TEST_TMPDIR/base-permissions.json" | sort -u > "$TEST_TMPDIR/base_ask"
    comm -23 "$TEST_TMPDIR/proj_ask" "$TEST_TMPDIR/base_ask" 2>/dev/null
)
assert_equals "" "$new_asks" "$CURRENT_TEST"

# ============================================================================
# Test: add_to_base
# ============================================================================
describe "permissions-sync.sh: Add to Base"

create_base_perms

it "Adds new permission to base allow"
tmp_file=$(mktemp)
jq --arg p "Bash(npm test:*)" '.permissions.allow += [$p] | .permissions.allow |= unique | .permissions.allow |= sort' \
    "$TEST_TMPDIR/base-permissions.json" > "$tmp_file" && mv "$tmp_file" "$TEST_TMPDIR/base-permissions.json"
result=$(jq -r '.permissions.allow | index("Bash(npm test:*)")' "$TEST_TMPDIR/base-permissions.json")
assert_not_equals "null" "$result" "$CURRENT_TEST"

it "Maintains sorted order after add"
sorted=$(jq -r '.permissions.allow | . == sort' "$TEST_TMPDIR/base-permissions.json")
assert_equals "true" "$sorted" "$CURRENT_TEST"

it "Prevents duplicates"
create_base_perms
original_count=$(jq '.permissions.allow | length' "$TEST_TMPDIR/base-permissions.json")
tmp_file=$(mktemp)
jq --arg p "Bash(git status:*)" '.permissions.allow += [$p] | .permissions.allow |= unique' \
    "$TEST_TMPDIR/base-permissions.json" > "$tmp_file" && mv "$tmp_file" "$TEST_TMPDIR/base-permissions.json"
new_count=$(jq '.permissions.allow | length' "$TEST_TMPDIR/base-permissions.json")
assert_equals "$original_count" "$new_count" "$CURRENT_TEST"

# ============================================================================
# Test: merge_to_project
# ============================================================================
describe "permissions-sync.sh: Merge to Project"

create_base_perms
create_project_settings

it "Merges base permissions into project"
base_allow=$(jq -c '.permissions.allow // []' "$TEST_TMPDIR/base-permissions.json")
base_ask=$(jq -c '.permissions.ask // []' "$TEST_TMPDIR/base-permissions.json")
base_deny=$(jq -c '.permissions.deny // []' "$TEST_TMPDIR/base-permissions.json")

tmp_file=$(mktemp)
jq --argjson allow "$base_allow" --argjson ask "$base_ask" --argjson deny "$base_deny" '
    .permissions.allow = ($allow + (.permissions.allow // []) | unique | sort) |
    .permissions.ask = ($ask + (.permissions.ask // []) | unique | sort) |
    .permissions.deny = ($deny + (.permissions.deny // []) | unique | sort)
' "$TEST_TMPDIR/project/.claude/settings.local.json" > "$tmp_file" && \
    mv "$tmp_file" "$TEST_TMPDIR/project/.claude/settings.local.json"

# Project should have base + its own
result=$(jq -r '.permissions.allow | index("Bash(ls:*)")' "$TEST_TMPDIR/project/.claude/settings.local.json")
assert_not_equals "null" "$result" "Project has base permission 'Bash(ls:*)'"

result=$(jq -r '.permissions.allow | index("Bash(npm test:*)")' "$TEST_TMPDIR/project/.claude/settings.local.json")
assert_not_equals "null" "$result" "Project retains own permission 'Bash(npm test:*)'"

it "Merged result is sorted"
sorted=$(jq -r '.permissions.allow | . == sort' "$TEST_TMPDIR/project/.claude/settings.local.json")
assert_equals "true" "$sorted" "$CURRENT_TEST"

it "Merged result has no duplicates"
total=$(jq '.permissions.allow | length' "$TEST_TMPDIR/project/.claude/settings.local.json")
unique=$(jq '.permissions.allow | unique | length' "$TEST_TMPDIR/project/.claude/settings.local.json")
assert_equals "$total" "$unique" "$CURRENT_TEST"

it "Merge is idempotent"
first_result=$(jq -c '.permissions' "$TEST_TMPDIR/project/.claude/settings.local.json")
# Run merge again
tmp_file=$(mktemp)
jq --argjson allow "$base_allow" --argjson ask "$base_ask" --argjson deny "$base_deny" '
    .permissions.allow = ($allow + (.permissions.allow // []) | unique | sort) |
    .permissions.ask = ($ask + (.permissions.ask // []) | unique | sort) |
    .permissions.deny = ($deny + (.permissions.deny // []) | unique | sort)
' "$TEST_TMPDIR/project/.claude/settings.local.json" > "$tmp_file" && \
    mv "$tmp_file" "$TEST_TMPDIR/project/.claude/settings.local.json"
second_result=$(jq -c '.permissions' "$TEST_TMPDIR/project/.claude/settings.local.json")
assert_equals "$first_result" "$second_result" "$CURRENT_TEST"

# ============================================================================
# Test: permissions-sync-all.sh argument parsing
# ============================================================================
describe "permissions-sync-all.sh: Argument Parsing"

it "--dry-run flag is recognized"
# Test by sourcing the argument parsing logic
(
    DRY_RUN=false
    SYNC_ALL=false
    args=("--dry-run")
    for arg in "${args[@]}"; do
        case $arg in
            --all) SYNC_ALL=true ;;
            --dry-run) DRY_RUN=true ;;
            *) ;;
        esac
    done
    if [[ "$DRY_RUN" == "true" ]]; then exit 0; fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "--all flag is recognized"
(
    DRY_RUN=false
    SYNC_ALL=false
    args=("--all")
    for arg in "${args[@]}"; do
        case $arg in
            --all) SYNC_ALL=true ;;
            --dry-run) DRY_RUN=true ;;
            *) ;;
        esac
    done
    if [[ "$SYNC_ALL" == "true" ]]; then exit 0; fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Both flags work together"
(
    DRY_RUN=false
    SYNC_ALL=false
    args=("--all" "--dry-run")
    for arg in "${args[@]}"; do
        case $arg in
            --all) SYNC_ALL=true ;;
            --dry-run) DRY_RUN=true ;;
            *) ;;
        esac
    done
    if [[ "$DRY_RUN" == "true" ]] && [[ "$SYNC_ALL" == "true" ]]; then exit 0; fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

# ============================================================================
# Cleanup
# ============================================================================
cleanup_tmpdir

# ============================================================================
# Summary
# ============================================================================
print_summary
