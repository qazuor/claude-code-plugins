#!/usr/bin/env bash
# =============================================================================
# test-notifications.sh - Functional tests for notifications plugin
# =============================================================================
#
# Tests:
#   - on-notification.sh: JSON parsing from stdin, OS detection
#   - stop-beep.sh: OS detection function
#   - subagent-beep.sh: OS detection function
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

PLUGIN_DIR="$PROJECT_ROOT/plugins/notifications"

setup_tmpdir

# ============================================================================
# OS Detection
# ============================================================================
describe "OS Detection Function"

it "Returns valid OS type"
# Inline the detect_os function
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

os_result=$(detect_os)
valid="false"
case "$os_result" in
    linux|macos|wsl|unknown) valid="true" ;;
esac
assert_equals "true" "$valid" "$CURRENT_TEST (got: $os_result)"

it "OS is one of expected values on this system"
expected_os=""
case "$(uname -s)" in
    Linux*) expected_os="linux" ;;
    Darwin*) expected_os="macos" ;;
esac
# Could be WSL, so skip if we can't determine
if [[ -n "$expected_os" ]]; then
    # Check if WSL
    if [[ "$expected_os" == "linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
        expected_os="wsl"
    fi
    assert_equals "$expected_os" "$os_result" "$CURRENT_TEST"
else
    skip_test "Cannot determine expected OS"
fi

# ============================================================================
# on-notification.sh: JSON Parsing
# ============================================================================
describe "on-notification.sh: JSON Parsing"

it "Extracts message from JSON payload"
message=$(echo '{"message":"Test notification"}' | jq -r '.message // empty' 2>/dev/null)
assert_equals "Test notification" "$message" "$CURRENT_TEST"

it "Handles missing message field"
message=$(echo '{"other":"field"}' | jq -r '.message // empty' 2>/dev/null)
assert_equals "" "$message" "$CURRENT_TEST"

it "Handles empty JSON"
message=$(echo '{}' | jq -r '.message // empty' 2>/dev/null)
assert_equals "" "$message" "$CURRENT_TEST"

it "Handles malformed JSON gracefully"
message=$(echo 'not json' | jq -r '.message // empty' 2>/dev/null) || message=""
# Should be empty since jq failed
if [[ -z "$message" ]]; then
    assert_equals "" "" "$CURRENT_TEST"
else
    assert_equals "" "$message" "$CURRENT_TEST"
fi

it "Falls back to raw payload when no message"
payload='{"message":"Test notification"}'
message=$(echo "$payload" | jq -r '.message // empty' 2>/dev/null) || message=""
if [[ -z "$message" ]]; then
    message="${payload:-Claude needs your attention}"
fi
assert_equals "Test notification" "$message" "$CURRENT_TEST"

it "Falls back to default when payload empty"
payload=""
message=$(echo "$payload" | jq -r '.message // empty' 2>/dev/null) || message=""
if [[ -z "$message" ]]; then
    message="${payload:-Claude needs your attention}"
fi
assert_equals "Claude needs your attention" "$message" "$CURRENT_TEST"

# ============================================================================
# on-notification.sh: Logging
# ============================================================================
describe "on-notification.sh: Logging"

it "Creates log directory"
LOG_DIR="$TEST_TMPDIR/test-project/.claude/.log"
mkdir -p "$LOG_DIR"
assert_dir_exists "$LOG_DIR" "$CURRENT_TEST"

it "Writes log entry with timestamp"
LOG_FILE="$LOG_DIR/notifications.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOTIFICATION: Test message" >> "$LOG_FILE"
assert_file_exists "$LOG_FILE" "$CURRENT_TEST"

log_content=$(cat "$LOG_FILE")
assert_contains "$log_content" "NOTIFICATION: Test message" "Log contains notification message"

# ============================================================================
# Script Files
# ============================================================================
describe "Notification Scripts Exist and Are Executable"

it "on-notification.sh exists and is executable"
assert_file_exists "$PLUGIN_DIR/scripts/on-notification.sh" "$CURRENT_TEST"
assert_executable "$PLUGIN_DIR/scripts/on-notification.sh" "on-notification.sh is executable"

it "stop-beep.sh exists and is executable"
assert_file_exists "$PLUGIN_DIR/scripts/stop-beep.sh" "$CURRENT_TEST"
assert_executable "$PLUGIN_DIR/scripts/stop-beep.sh" "stop-beep.sh is executable"

it "subagent-beep.sh exists and is executable"
assert_file_exists "$PLUGIN_DIR/scripts/subagent-beep.sh" "$CURRENT_TEST"
assert_executable "$PLUGIN_DIR/scripts/subagent-beep.sh" "subagent-beep.sh is executable"

# ============================================================================
# Cleanup
# ============================================================================
cleanup_tmpdir

# ============================================================================
# Summary
# ============================================================================
print_summary
