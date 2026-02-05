#!/usr/bin/env bash
# =============================================================================
# test-hooks.sh - Hook configuration validation tests
# =============================================================================
#
# Validates:
#   - hooks.json files have valid structure
#   - Hook events are valid Claude Code events
#   - Hook commands reference existing scripts
#   - Hook timeouts are reasonable
#   - All hook types are "command"
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

VALID_EVENTS=("PreToolUse" "PostToolUse" "Notification" "Stop" "SubagentStop" "SessionStart" "PreCompact")

# ============================================================================
# Hook Files Exist
# ============================================================================
describe "Hook Files Exist"

PLUGINS_WITH_HOOKS=("notifications" "task-master" "permission-sync" "session-tools" "knowledge-sync")

for plugin in "${PLUGINS_WITH_HOOKS[@]}"; do
    it "hooks.json exists: $plugin"
    assert_file_exists "$PROJECT_ROOT/plugins/$plugin/hooks/hooks.json" "$CURRENT_TEST"
done

# ============================================================================
# Hook Structure
# ============================================================================
describe "Hook Structure"

while IFS= read -r hooks_file; do
    [[ -f "$hooks_file" ]] || continue
    relative_path="${hooks_file#"$PROJECT_ROOT/plugins/"}"
    plugin_name="${relative_path%%/*}"

    it "hooks.json has 'hooks' key: $plugin_name"
    assert_json_has_key "$hooks_file" ".hooks" "$CURRENT_TEST"

    it "hooks.json has 'description': $plugin_name"
    assert_json_has_key "$hooks_file" ".description" "$CURRENT_TEST"

    # Extract event names
    events=$(jq -r '.hooks | keys[]' "$hooks_file" 2>/dev/null)

    for event in $events; do
        # Validate event name
        it "Valid hook event '$event': $plugin_name"
        is_valid="false"
        for valid_event in "${VALID_EVENTS[@]}"; do
            if [[ "$event" == "$valid_event" ]]; then
                is_valid="true"
                break
            fi
        done
        assert_equals "true" "$is_valid" "$CURRENT_TEST"

        # Check hook entries
        hook_count=$(jq ".hooks[\"$event\"] | length" "$hooks_file")
        it "Event '$event' has entries: $plugin_name"
        assert_gt "$hook_count" 0 "$CURRENT_TEST"

        # Check each hook entry
        for i in $(seq 0 $((hook_count - 1))); do
            inner_count=$(jq ".hooks[\"$event\"][$i].hooks | length" "$hooks_file")

            for j in $(seq 0 $((inner_count - 1))); do
                # Validate type is "command"
                hook_type=$(jq -r ".hooks[\"$event\"][$i].hooks[$j].type" "$hooks_file")
                it "Hook type is 'command': $plugin_name/${event}[${i}][${j}]"
                assert_equals "command" "$hook_type" "$CURRENT_TEST"

                # Validate command references a script
                hook_cmd=$(jq -r ".hooks[\"$event\"][$i].hooks[$j].command" "$hooks_file")
                it "Hook command is set: $plugin_name/${event}[${i}][${j}]"
                assert_not_equals "" "$hook_cmd" "$CURRENT_TEST"

                # Check that referenced script exists (resolve CLAUDE_PLUGIN_ROOT)
                script_path="${hook_cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$PROJECT_ROOT/plugins/$plugin_name}"
                it "Hook script exists: $(basename "$script_path")"
                assert_file_exists "$script_path" "$CURRENT_TEST"

                it "Hook script is executable: $(basename "$script_path")"
                assert_executable "$script_path" "$CURRENT_TEST"

                # Validate timeout
                timeout_val=$(jq -r ".hooks[\"$event\"][$i].hooks[$j].timeout // empty" "$hooks_file")
                if [[ -n "$timeout_val" ]]; then
                    it "Timeout is positive: $plugin_name/$event ($timeout_val)"
                    assert_gt "$timeout_val" 0 "$CURRENT_TEST"

                    it "Timeout is reasonable (<= 60s): $plugin_name/$event ($timeout_val)"
                    is_reasonable="true"
                    if [[ "$timeout_val" -gt 60 ]]; then
                        is_reasonable="false"
                    fi
                    assert_equals "true" "$is_reasonable" "$CURRENT_TEST"
                fi
            done
        done
    done
done < <(find "$PROJECT_ROOT/plugins" -path "*/hooks/hooks.json" -type f 2>/dev/null)

# ============================================================================
# Specific Hook Assignments
# ============================================================================
describe "Expected Hook Assignments"

# notifications: Notification, Stop, SubagentStop
it "notifications has Notification hook"
assert_json_has_key "$PROJECT_ROOT/plugins/notifications/hooks/hooks.json" '.hooks.Notification' "$CURRENT_TEST"

it "notifications has Stop hook"
assert_json_has_key "$PROJECT_ROOT/plugins/notifications/hooks/hooks.json" '.hooks.Stop' "$CURRENT_TEST"

it "notifications has SubagentStop hook"
assert_json_has_key "$PROJECT_ROOT/plugins/notifications/hooks/hooks.json" '.hooks.SubagentStop' "$CURRENT_TEST"

# permission-sync: SessionStart
it "permission-sync has SessionStart hook"
assert_json_has_key "$PROJECT_ROOT/plugins/permission-sync/hooks/hooks.json" '.hooks.SessionStart' "$CURRENT_TEST"

# session-tools: PreCompact
it "session-tools has PreCompact hook"
assert_json_has_key "$PROJECT_ROOT/plugins/session-tools/hooks/hooks.json" '.hooks.PreCompact' "$CURRENT_TEST"

# knowledge-sync: SessionStart
it "knowledge-sync has SessionStart hook"
assert_json_has_key "$PROJECT_ROOT/plugins/knowledge-sync/hooks/hooks.json" '.hooks.SessionStart' "$CURRENT_TEST"

# task-master: SessionStart
it "task-master has SessionStart hook"
assert_json_has_key "$PROJECT_ROOT/plugins/task-master/hooks/hooks.json" '.hooks.SessionStart' "$CURRENT_TEST"

# ============================================================================
# Summary
# ============================================================================
print_summary
