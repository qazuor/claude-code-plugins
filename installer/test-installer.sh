#!/usr/bin/env bash
set -euo pipefail

# Claude Code Plugins — Installer Tests
# Validates installer scripts work correctly.
# Usage: ./installer/test-installer.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Colors (auto-disable when stdout is not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "  ${GREEN}PASS${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "  ${RED}FAIL${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

echo "Running installer tests..."
echo ""

# ---------------------------------------------------------------------------
# Test 1: All scripts have valid bash syntax
# ---------------------------------------------------------------------------
echo "Test: Bash syntax validation"
for script in "$SCRIPT_DIR"/*.sh; do
    script_name=$(basename "$script")
    if bash -n "$script" 2>/dev/null; then
        pass "$script_name has valid syntax"
    else
        fail "$script_name has syntax errors"
    fi
done
echo ""

# ---------------------------------------------------------------------------
# Test 2: All scripts have proper shebang
# ---------------------------------------------------------------------------
echo "Test: Shebang validation"
for script in "$SCRIPT_DIR"/*.sh; do
    script_name=$(basename "$script")
    first_line=$(head -n 1 "$script")
    if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
        pass "$script_name has correct shebang"
    else
        fail "$script_name missing or incorrect shebang: $first_line"
    fi
done
echo ""

# ---------------------------------------------------------------------------
# Test 3: All scripts have set -euo pipefail
# ---------------------------------------------------------------------------
echo "Test: Error handling (set -euo pipefail)"
for script in "$SCRIPT_DIR"/*.sh; do
    script_name=$(basename "$script")
    if grep -q "set -euo pipefail" "$script"; then
        pass "$script_name has error handling"
    else
        fail "$script_name missing 'set -euo pipefail'"
    fi
done
echo ""

# ---------------------------------------------------------------------------
# Test 4: All scripts validate HOME
# ---------------------------------------------------------------------------
echo "Test: HOME validation"
for script in install.sh update.sh uninstall.sh; do
    script_path="$SCRIPT_DIR/$script"
    [ -f "$script_path" ] || continue
    if grep -q 'HOME:-' "$script_path"; then
        pass "$script validates HOME"
    else
        fail "$script missing HOME validation"
    fi
done
echo ""

# ---------------------------------------------------------------------------
# Test 5: Profile JSON files are valid
# ---------------------------------------------------------------------------
echo "Test: Profile JSON validity"
if command -v jq &> /dev/null; then
    for profile in "$SCRIPT_DIR/profiles"/*.json; do
        profile_name=$(basename "$profile")
        if jq empty "$profile" 2>/dev/null; then
            pass "$profile_name is valid JSON"
        else
            fail "$profile_name is invalid JSON"
        fi
    done

    # Test: All profile plugins reference existing directories
    echo ""
    echo "Test: Profile plugin references"
    for profile in "$SCRIPT_DIR/profiles"/*.json; do
        profile_name=$(basename "$profile")
        plugins=$(jq -r '.plugins[]' "$profile")
        all_exist=true
        for plugin in $plugins; do
            if [ ! -d "$REPO_DIR/plugins/$plugin" ]; then
                fail "$profile_name references non-existent plugin: $plugin"
                all_exist=false
            fi
        done
        if [ "$all_exist" = true ]; then
            pass "$profile_name all plugins exist"
        fi
    done
else
    echo -e "  ${YELLOW}SKIP${NC} jq not installed, skipping JSON tests"
fi
echo ""

# ---------------------------------------------------------------------------
# Test 6: Color auto-disable (scripts support non-terminal output)
# ---------------------------------------------------------------------------
echo "Test: Terminal color detection"
for script in install.sh update.sh uninstall.sh; do
    script_path="$SCRIPT_DIR/$script"
    [ -f "$script_path" ] || continue
    if grep -q '\[ -t 1 \]' "$script_path"; then
        pass "$script has terminal detection for colors"
    else
        fail "$script missing terminal detection for colors"
    fi
done
echo ""

# ---------------------------------------------------------------------------
# Test 7: hooks.json files are valid JSON
# ---------------------------------------------------------------------------
echo "Test: hooks.json validity"
if command -v jq &> /dev/null; then
    hooks_found=false
    for hooks_file in "$REPO_DIR"/plugins/*/hooks/hooks.json; do
        [ -f "$hooks_file" ] || continue
        hooks_found=true
        plugin_name=$(basename "$(dirname "$(dirname "$hooks_file")")")
        if jq empty "$hooks_file" 2>/dev/null; then
            pass "$plugin_name/hooks/hooks.json is valid JSON"
        else
            fail "$plugin_name/hooks/hooks.json is invalid JSON"
        fi
    done
    if [ "$hooks_found" = false ]; then
        echo -e "  ${YELLOW}SKIP${NC} No hooks.json files found"
    fi
else
    echo -e "  ${YELLOW}SKIP${NC} jq not installed, skipping JSON tests"
fi
echo ""

# ---------------------------------------------------------------------------
# Test 8: hooks.json contains required placeholders
# ---------------------------------------------------------------------------
echo "Test: hooks.json placeholder validation"
for hooks_file in "$REPO_DIR"/plugins/*/hooks/hooks.json; do
    [ -f "$hooks_file" ] || continue
    plugin_name=$(basename "$(dirname "$(dirname "$hooks_file")")")
    if grep -q '\${CLAUDE_PLUGIN_ROOT}' "$hooks_file"; then
        pass "$plugin_name/hooks/hooks.json uses \${CLAUDE_PLUGIN_ROOT} placeholder"
    else
        fail "$plugin_name/hooks/hooks.json missing \${CLAUDE_PLUGIN_ROOT} placeholder (hardcoded paths?)"
    fi
done
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "================================"
total=$((TESTS_PASSED + TESTS_FAILED))
echo -e "Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC} (total: $total)"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi
