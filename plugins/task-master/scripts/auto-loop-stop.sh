#!/usr/bin/env bash
# Task Master - Auto-Loop Stop Hook
# Runs on session Stop event. If an auto-loop is active and has remaining
# iterations, outputs a systemMessage instructing Claude to continue.

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
LOOP_FILE="${PROJECT_ROOT}/.claude/auto-loop.local.md"

# Exit silently if no active loop
[ -f "$LOOP_FILE" ] || exit 0

# Parse YAML frontmatter values using grep/cut
get_frontmatter_value() {
    local key="$1"
    grep "^${key}:" "$LOOP_FILE" 2>/dev/null | head -n 1 | cut -d':' -f2- | sed 's/^ *//' || echo ""
}

ITERATION=$(get_frontmatter_value "iteration")
MAX_ITERATIONS=$(get_frontmatter_value "max_iterations")

# Validate we got numeric values
if ! [[ "$ITERATION" =~ ^[0-9]+$ ]] || ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    exit 0
fi

# If max iterations reached, clean up and exit
if [ "$ITERATION" -gt "$MAX_ITERATIONS" ]; then
    rm -f "$LOOP_FILE"
    exit 0
fi

# Check if there are pending tasks in state files
TASKS_DIR="${PROJECT_ROOT}/.claude/tasks"
HAS_PENDING=false

if [ -d "$TASKS_DIR" ] && command -v jq &>/dev/null; then
    for state_file in "$TASKS_DIR"/*/state.json "$TASKS_DIR/standalone/state.json"; do
        [ -f "$state_file" ] || continue
        pending_count=$(jq '[.tasks[] | select(.status == "pending")] | length' "$state_file" 2>/dev/null || echo "0")
        if [ "$pending_count" -gt 0 ]; then
            HAS_PENDING=true
            break
        fi
    done
fi

# If no pending tasks, clean up and exit
if [ "$HAS_PENDING" = false ]; then
    rm -f "$LOOP_FILE"
    exit 0
fi

# Read guardrails if they exist
GUARDRAILS=""
GUARDRAILS_FILE="${PROJECT_ROOT}/.claude/guardrails.md"
if [ -f "$GUARDRAILS_FILE" ]; then
    GUARDRAILS=$(grep "^- \*\*GR-" "$GUARDRAILS_FILE" 2>/dev/null || true)
fi

# Output continuation message for Claude
echo "Auto-loop active: iteration ${ITERATION}/${MAX_ITERATIONS}."
echo "Pending tasks remain. Continue with /next-task to pick the next available task."
echo "Use /auto-loop-cancel to stop the loop."
if [ -n "$GUARDRAILS" ]; then
    echo ""
    echo "Active guardrails:"
    echo "$GUARDRAILS"
fi
