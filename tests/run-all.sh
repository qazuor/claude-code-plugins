#!/usr/bin/env bash
# =============================================================================
# run-all.sh - Run all test suites
# =============================================================================
#
# Usage:
#   ./tests/run-all.sh           # Run all tests
#   ./tests/run-all.sh structure # Run specific test suite
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' RED='' CYAN='' BOLD='' NC=''
fi

# All test suites
ALL_SUITES=(
    "structure"
    "hooks"
    "permissions-sync"
    "knowledge-sync"
    "session-tools"
    "notifications"
    "task-master"
    "mcp-servers"
    "claude-initializer"
)

# Track results
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
SUITE_RESULTS=()

run_suite() {
    local suite="$1"
    local test_file="$SCRIPT_DIR/test-${suite}.sh"

    if [[ ! -f "$test_file" ]]; then
        echo -e "${RED}Test file not found: $test_file${NC}"
        return 1
    fi

    echo -e "\n${BOLD}${CYAN}========================================${NC}"
    echo -e "${BOLD}${CYAN}  Test Suite: ${suite}${NC}"
    echo -e "${BOLD}${CYAN}========================================${NC}"

    local output
    local exit_code=0
    output=$(bash "$test_file" 2>&1) || exit_code=$?

    echo "$output"

    # Parse results from output
    local passed failed skipped
    passed=$(echo "$output" | grep -oP '\d+(?= passed)' | tail -1) || passed=0
    failed=$(echo "$output" | grep -oP '\d+(?= failed)' | tail -1) || failed=0
    skipped=$(echo "$output" | grep -oP '\d+(?= skipped)' | tail -1) || skipped=0

    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + skipped))

    if [[ $exit_code -eq 0 ]]; then
        SUITE_RESULTS+=("${GREEN}PASS${NC} $suite")
    else
        SUITE_RESULTS+=("${RED}FAIL${NC} $suite")
    fi

    return "$exit_code"
}

# Determine which suites to run
SUITES_TO_RUN=()
if [[ $# -gt 0 ]]; then
    for arg in "$@"; do
        SUITES_TO_RUN+=("$arg")
    done
else
    SUITES_TO_RUN=("${ALL_SUITES[@]}")
fi

# Check prerequisites
echo -e "${BOLD}Checking prerequisites...${NC}"
if ! command -v jq &>/dev/null; then
    echo -e "${RED}ERROR: jq is required. Install it with: sudo apt install jq${NC}"
    exit 1
fi
echo -e "  ${GREEN}jq${NC} available"
echo ""

# Run suites
FAILURES=0
for suite in "${SUITES_TO_RUN[@]}"; do
    if ! run_suite "$suite"; then
        FAILURES=$((FAILURES + 1))
    fi
done

# Print overall summary
echo -e "\n${BOLD}${CYAN}========================================${NC}"
echo -e "${BOLD}${CYAN}  OVERALL RESULTS${NC}"
echo -e "${BOLD}${CYAN}========================================${NC}"
echo ""

for result in "${SUITE_RESULTS[@]}"; do
    echo -e "  $result"
done

echo ""
GRAND_TOTAL=$((TOTAL_PASSED + TOTAL_FAILED + TOTAL_SKIPPED))
echo -e "${BOLD}Total:${NC} ${GREEN}${TOTAL_PASSED} passed${NC}, ${RED}${TOTAL_FAILED} failed${NC}, ${YELLOW:-}${TOTAL_SKIPPED} skipped${NC} (${GRAND_TOTAL} tests)"
echo ""

if [[ $FAILURES -gt 0 ]]; then
    echo -e "${RED}${BOLD}$FAILURES suite(s) failed${NC}"
    exit 1
else
    echo -e "${GREEN}${BOLD}All suites passed!${NC}"
    exit 0
fi
