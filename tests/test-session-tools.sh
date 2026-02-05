#!/usr/bin/env bash
# =============================================================================
# test-session-tools.sh - Functional tests for session-tools plugin
# =============================================================================
#
# Tests:
#   - pre-compact-diary.sh: output validation
#   - claude-mem-watchdog.sh: early exit when not installed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

PLUGIN_DIR="$PROJECT_ROOT/plugins/session-tools"

setup_tmpdir

# ============================================================================
# pre-compact-diary.sh
# ============================================================================
describe "pre-compact-diary.sh: Output"

it "Outputs diary instruction"
output=$("$PLUGIN_DIR/scripts/pre-compact-diary.sh" 2>&1)
assert_contains "$output" "diary" "$CURRENT_TEST"

it "Mentions compacting"
output=$("$PLUGIN_DIR/scripts/pre-compact-diary.sh" 2>&1)
assert_contains "$output" "compact" "$CURRENT_TEST"

it "Includes /diary command"
output=$("$PLUGIN_DIR/scripts/pre-compact-diary.sh" 2>&1)
assert_contains "$output" "/diary" "$CURRENT_TEST"

it "Exits with code 0"
"$PLUGIN_DIR/scripts/pre-compact-diary.sh" >/dev/null 2>&1
assert_exit_code "0" "$?" "$CURRENT_TEST"

# ============================================================================
# claude-mem-watchdog.sh: Early Exit
# ============================================================================
describe "claude-mem-watchdog.sh: Early Exit When Not Installed"

it "Exits 0 when claude-mem directory missing"
(
    export HOME="$TEST_TMPDIR"
    export CLAUDE_MEM_DATA_DIR="$TEST_TMPDIR/.claude-mem-fake"
    # No claude-mem dir
    if [ ! -d "$CLAUDE_MEM_DATA_DIR" ] || [ ! -f "$CLAUDE_MEM_DATA_DIR/cm-hook.sh" ]; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Exits 0 when cm-hook.sh missing"
(
    export HOME="$TEST_TMPDIR"
    export CLAUDE_MEM_DATA_DIR="$TEST_TMPDIR/.claude-mem-no-hook"
    mkdir -p "$CLAUDE_MEM_DATA_DIR"
    # Dir exists but no cm-hook.sh
    if [ ! -d "$CLAUDE_MEM_DATA_DIR" ] || [ ! -f "$CLAUDE_MEM_DATA_DIR/cm-hook.sh" ]; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

# ============================================================================
# Command files
# ============================================================================
describe "Session Tools Commands"

it "diary.md exists"
assert_file_exists "$PLUGIN_DIR/commands/diary.md" "$CURRENT_TEST"

it "reflect.md exists"
assert_file_exists "$PLUGIN_DIR/commands/reflect.md" "$CURRENT_TEST"

it "diary.md has frontmatter"
first_line=$(head -n 1 "$PLUGIN_DIR/commands/diary.md")
assert_equals "---" "$first_line" "$CURRENT_TEST"

it "reflect.md has frontmatter"
first_line=$(head -n 1 "$PLUGIN_DIR/commands/reflect.md")
assert_equals "---" "$first_line" "$CURRENT_TEST"

# ============================================================================
# Cleanup
# ============================================================================
cleanup_tmpdir

# ============================================================================
# Summary
# ============================================================================
print_summary
