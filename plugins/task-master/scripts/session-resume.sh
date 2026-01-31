#!/usr/bin/env bash
# Task Master - Session Resume Detection
# This script runs on SessionStart to detect active tasks/specs
# and provide context to Claude about ongoing work.

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
TASKS_DIR="${PROJECT_ROOT}/.claude/tasks"
INDEX_FILE="${TASKS_DIR}/index.json"

# Check if task index exists
if [ ! -f "$INDEX_FILE" ]; then
  exit 0
fi

# Read index and check for active work
ACTIVE_EPICS=""
STANDALONE_TOTAL=0
STANDALONE_COMPLETED=0
HAS_ACTIVE_WORK=false

# Parse index.json for active epics
if command -v jq &>/dev/null; then
  EPIC_COUNT=$(jq '.epics | length' "$INDEX_FILE" 2>/dev/null || echo "0")

  for i in $(seq 0 $((EPIC_COUNT - 1))); do
    STATUS=$(jq -r ".epics[$i].status" "$INDEX_FILE" 2>/dev/null || echo "")
    if [ "$STATUS" = "in-progress" ] || [ "$STATUS" = "pending" ]; then
      HAS_ACTIVE_WORK=true
      SPEC_ID=$(jq -r ".epics[$i].specId" "$INDEX_FILE" 2>/dev/null || echo "unknown")
      TITLE=$(jq -r ".epics[$i].title" "$INDEX_FILE" 2>/dev/null || echo "unknown")
      PROGRESS=$(jq -r ".epics[$i].progress" "$INDEX_FILE" 2>/dev/null || echo "0/0")
      ACTIVE_EPICS="${ACTIVE_EPICS}\n  - ${SPEC_ID}: ${TITLE} (${PROGRESS} tasks, status: ${STATUS})"
    fi
  done

  STANDALONE_TOTAL=$(jq '.standalone.total // 0' "$INDEX_FILE" 2>/dev/null || echo "0")
  STANDALONE_COMPLETED=$(jq '.standalone.completed // 0' "$INDEX_FILE" 2>/dev/null || echo "0")
  STANDALONE_PENDING=$((STANDALONE_TOTAL - STANDALONE_COMPLETED))

  if [ "$STANDALONE_PENDING" -gt 0 ]; then
    HAS_ACTIVE_WORK=true
  fi
else
  # Fallback without jq: check if file has content suggesting active work
  if grep -q '"in-progress"' "$INDEX_FILE" 2>/dev/null || grep -q '"pending"' "$INDEX_FILE" 2>/dev/null; then
    HAS_ACTIVE_WORK=true
  fi
fi

# Only output if there's active work
if [ "$HAS_ACTIVE_WORK" = true ]; then
  echo "task-master:session-resume"
  echo ""
  echo "Active Task Master work detected:"

  if [ -n "$ACTIVE_EPICS" ]; then
    echo ""
    echo "Active Epics:"
    echo -e "$ACTIVE_EPICS"
  fi

  if [ "$STANDALONE_PENDING" -gt 0 ] 2>/dev/null; then
    echo ""
    echo "Standalone Tasks: ${STANDALONE_PENDING} pending (${STANDALONE_COMPLETED}/${STANDALONE_TOTAL} completed)"
  fi

  echo ""
  echo "Use /tasks for full dashboard, /next-task to continue working."
fi
