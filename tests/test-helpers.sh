#!/usr/bin/env bash
# =============================================================================
# test-helpers.sh - Lightweight bash test framework
# =============================================================================
#
# Provides assert functions, test tracking, and colored output.
# Source this file at the top of each test file.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST=""

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' BOLD='' NC=''
fi

# ---------------------------------------------------------------------------
# Temp directory for test fixtures
# ---------------------------------------------------------------------------
TEST_TMPDIR=""

setup_tmpdir() {
    TEST_TMPDIR=$(mktemp -d)
}

cleanup_tmpdir() {
    if [[ -n "$TEST_TMPDIR" ]] && [[ -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------
describe() {
    echo -e "\n${CYAN}${BOLD}$1${NC}"
}

it() {
    CURRENT_TEST="$1"
}

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------
assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-$CURRENT_TEST}"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Expected: ${expected}"
        echo -e "       Actual:   ${actual}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local msg="${3:-$CURRENT_TEST}"

    if [[ "$unexpected" != "$actual" ]]; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Should not equal: ${unexpected}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-$CURRENT_TEST}"

    if echo "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Expected to contain: ${needle}"
        echo -e "       In: ${haystack:0:200}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-$CURRENT_TEST}"

    if ! echo "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Should not contain: ${needle}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local msg="${2:-File exists: $file}"

    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       File not found: ${file}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_dir_exists() {
    local dir="$1"
    local msg="${2:-Directory exists: $dir}"

    if [[ -d "$dir" ]]; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Directory not found: ${dir}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_executable() {
    local file="$1"
    local msg="${2:-File is executable: $file}"

    if [[ -x "$file" ]]; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Not executable: ${file}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_true() {
    local condition="$1"
    local msg="${2:-$CURRENT_TEST}"

    if eval "$condition"; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Condition failed: ${condition}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-Exit code is $expected}"

    assert_equals "$expected" "$actual" "$msg"
}

assert_json_valid() {
    local file="$1"
    local msg="${2:-Valid JSON: $file}"

    if jq empty "$file" 2>/dev/null; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Invalid JSON: ${file}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_json_has_key() {
    local file="$1"
    local key="$2"
    # shellcheck disable=SC2016
    local msg="${3:-JSON has key '$key': $file}"

    if jq -e "$key" "$file" >/dev/null 2>&1; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Key not found: ${key}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_gt() {
    local actual="$1"
    local threshold="$2"
    local msg="${3:-$actual > $threshold}"

    if [[ "$actual" -gt "$threshold" ]]; then
        echo -e "  ${GREEN}PASS${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC} $msg"
        echo -e "       Expected > ${threshold}, got ${actual}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

skip_test() {
    local msg="${1:-$CURRENT_TEST}"
    echo -e "  ${YELLOW}SKIP${NC} $msg"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    echo ""
    echo -e "${BOLD}Results:${NC} ${GREEN}${TESTS_PASSED} passed${NC}, ${RED}${TESTS_FAILED} failed${NC}, ${YELLOW}${TESTS_SKIPPED} skipped${NC} (${total} total)"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}
