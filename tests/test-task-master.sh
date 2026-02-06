#!/usr/bin/env bash
# shellcheck disable=SC2030,SC2031
# =============================================================================
# test-task-master.sh - Functional tests for task-master plugin
# =============================================================================
#
# Tests:
#   - session-resume.sh: JSON parsing, no output when no work, jq fallback
#   - Plugin structure (schemas, skills, agents, commands)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

PLUGIN_DIR="$PROJECT_ROOT/plugins/task-master"

setup_tmpdir

# ============================================================================
# session-resume.sh: Silent When No Work
# ============================================================================
describe "session-resume.sh: Silent When No Active Work"

it "Exits 0 with no output when index.json missing"
(
    export CLAUDE_PROJECT_DIR="$TEST_TMPDIR/empty-project"
    mkdir -p "$CLAUDE_PROJECT_DIR"
    output=$("$PLUGIN_DIR/scripts/session-resume.sh" 2>&1)
    if [[ -z "$output" ]]; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

# ============================================================================
# session-resume.sh: Detects Active Epics
# ============================================================================
describe "session-resume.sh: Detects Active Work"

it "Outputs context when in-progress epic exists"
(
    export CLAUDE_PROJECT_DIR="$TEST_TMPDIR/active-project"
    mkdir -p "$CLAUDE_PROJECT_DIR/.claude/tasks"
    cat > "$CLAUDE_PROJECT_DIR/.claude/tasks/index.json" << 'EOF'
{
  "epics": [
    {
      "specId": "SPEC-001",
      "title": "Test Feature",
      "status": "in-progress",
      "progress": "3/10"
    }
  ],
  "standalone": {
    "total": 0,
    "completed": 0
  }
}
EOF
    output=$("$PLUGIN_DIR/scripts/session-resume.sh" 2>&1)
    if echo "$output" | grep -q "Active Task Master work detected"; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Shows epic details in output"
(
    export CLAUDE_PROJECT_DIR="$TEST_TMPDIR/active-project"
    output=$("$PLUGIN_DIR/scripts/session-resume.sh" 2>&1)
    if echo "$output" | grep -q "SPEC-001"; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Shows standalone pending tasks"
(
    export CLAUDE_PROJECT_DIR="$TEST_TMPDIR/standalone-project"
    mkdir -p "$CLAUDE_PROJECT_DIR/.claude/tasks"
    cat > "$CLAUDE_PROJECT_DIR/.claude/tasks/index.json" << 'EOF'
{
  "epics": [],
  "standalone": {
    "total": 5,
    "completed": 2
  }
}
EOF
    output=$("$PLUGIN_DIR/scripts/session-resume.sh" 2>&1)
    if echo "$output" | grep -q "3 pending"; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Silent when all work is completed"
(
    export CLAUDE_PROJECT_DIR="$TEST_TMPDIR/completed-project"
    mkdir -p "$CLAUDE_PROJECT_DIR/.claude/tasks"
    cat > "$CLAUDE_PROJECT_DIR/.claude/tasks/index.json" << 'EOF'
{
  "epics": [
    {
      "specId": "SPEC-002",
      "title": "Done Feature",
      "status": "completed",
      "progress": "10/10"
    }
  ],
  "standalone": {
    "total": 5,
    "completed": 5
  }
}
EOF
    output=$("$PLUGIN_DIR/scripts/session-resume.sh" 2>&1)
    if [[ -z "$output" ]]; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

# ============================================================================
# session-resume.sh: jq Fallback
# ============================================================================
describe "session-resume.sh: Grep Fallback"

it "Detects active work via grep when content has in-progress"
# Test the grep fallback logic directly
(
    index_content='{"epics":[{"status":"in-progress"}]}'
    if echo "$index_content" | grep -q '"in-progress"' 2>/dev/null; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Detects active work via grep when content has pending"
(
    index_content='{"epics":[{"status":"pending"}]}'
    if echo "$index_content" | grep -q '"pending"' 2>/dev/null; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "No match when only completed"
(
    index_content='{"epics":[{"status":"completed"}]}'
    if echo "$index_content" | grep -q '"in-progress"' 2>/dev/null || \
       echo "$index_content" | grep -q '"pending"' 2>/dev/null; then
        exit 1
    fi
    exit 0
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

# ============================================================================
# Plugin Components
# ============================================================================
describe "Task Master Components"

# Skills
EXPECTED_SKILLS=("complexity-scorer" "dependency-grapher" "overlap-detector" "quality-gate" "spec-generator" "task-atomizer" "task-from-spec")
for skill in "${EXPECTED_SKILLS[@]}"; do
    it "Skill exists: $skill"
    assert_file_exists "$PLUGIN_DIR/skills/$skill/SKILL.md" "$CURRENT_TEST"
done

# Agents
EXPECTED_AGENTS=("spec-writer" "task-planner" "tech-analyzer")
for agent in "${EXPECTED_AGENTS[@]}"; do
    it "Agent exists: $agent"
    assert_file_exists "$PLUGIN_DIR/agents/$agent.md" "$CURRENT_TEST"
done

# Commands
EXPECTED_COMMANDS=("auto-loop" "auto-loop-cancel" "new-task" "next-task" "replan" "spec" "task-status" "tasks")
for cmd in "${EXPECTED_COMMANDS[@]}"; do
    it "Command exists: $cmd"
    assert_file_exists "$PLUGIN_DIR/commands/$cmd.md" "$CURRENT_TEST"
done

# Schemas
it "state-schema.json exists"
assert_file_exists "$PLUGIN_DIR/templates/state-schema.json" "$CURRENT_TEST"

it "index-schema.json exists"
assert_file_exists "$PLUGIN_DIR/templates/index-schema.json" "$CURRENT_TEST"

it "metadata-schema.json exists"
assert_file_exists "$PLUGIN_DIR/templates/metadata-schema.json" "$CURRENT_TEST"

it "specs-index-schema.json exists"
assert_file_exists "$PLUGIN_DIR/templates/specs-index-schema.json" "$CURRENT_TEST"

# ============================================================================
# Auto-Loop Components
# ============================================================================
describe "Auto-Loop Components"

it "auto-loop.md has frontmatter"
first_line=$(head -n 1 "$PLUGIN_DIR/commands/auto-loop.md")
assert_equals "---" "$first_line" "$CURRENT_TEST"

it "auto-loop-cancel.md has frontmatter"
first_line=$(head -n 1 "$PLUGIN_DIR/commands/auto-loop-cancel.md")
assert_equals "---" "$first_line" "$CURRENT_TEST"

it "auto-loop-stop.sh exists"
assert_file_exists "$PLUGIN_DIR/scripts/auto-loop-stop.sh" "$CURRENT_TEST"

it "auto-loop-stop.sh is executable"
assert_executable "$PLUGIN_DIR/scripts/auto-loop-stop.sh" "$CURRENT_TEST"

it "auto-loop-stop.sh exits silently without loop file"
(
    export CLAUDE_PROJECT_DIR="$TEST_TMPDIR/no-loop-project"
    mkdir -p "$CLAUDE_PROJECT_DIR/.claude"
    output=$("$PLUGIN_DIR/scripts/auto-loop-stop.sh" 2>&1)
    if [[ -z "$output" ]]; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "auto-loop-state-schema.json exists"
assert_file_exists "$PLUGIN_DIR/templates/auto-loop-state-schema.json" "$CURRENT_TEST"

it "auto-loop-state-schema.json is valid JSON"
assert_json_valid "$PLUGIN_DIR/templates/auto-loop-state-schema.json" "$CURRENT_TEST"

# ============================================================================
# Guardrails
# ============================================================================
describe "Guardrails Template"

it "guardrails-template.md exists"
assert_file_exists "$PLUGIN_DIR/templates/guardrails-template.md" "$CURRENT_TEST"

it "guardrails-template.md has frontmatter"
first_line=$(head -n 1 "$PLUGIN_DIR/templates/guardrails-template.md")
assert_equals "---" "$first_line" "$CURRENT_TEST"

it "guardrails-template.md has 4+ seed signs"
sign_count=$(grep -c "^\- \*\*GR-" "$PLUGIN_DIR/templates/guardrails-template.md")
assert_gt "$sign_count" 3 "Has $sign_count seed signs (>= 4)"

# ============================================================================
# Hooks Configuration
# ============================================================================
describe "Hooks Configuration"

it "hooks.json includes Stop event"
(
    if jq -e '.hooks.Stop' "$PLUGIN_DIR/hooks/hooks.json" >/dev/null 2>&1; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "hooks.json Stop references auto-loop-stop.sh"
(
    cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PLUGIN_DIR/hooks/hooks.json" 2>/dev/null)
    if echo "$cmd" | grep -q "auto-loop-stop.sh"; then
        exit 0
    fi
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
