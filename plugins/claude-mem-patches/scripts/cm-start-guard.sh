#!/bin/bash
# =============================================================================
# cm-start-guard.sh - Fast-fail worker startup guard for claude-mem hooks
# =============================================================================
#
# Replaces direct "bun worker-service.cjs start" calls in hooks to prevent
# blocking when the worker is slow or unresponsive.
#
# Strategy:
# 1. Quick health check (2s timeout)
# 2. If healthy: exit 0 immediately (no blocking)
# 3. If not healthy: try to start with short timeout (5s)
# 4. If start fails: exit 0 anyway (watchdog handles recovery)
#
# This ensures hooks never block for more than ~7 seconds total,
# compared to the default 15s+ timeout that freezes Claude Code.
#
# Installation: Installed by claude-mem-patches apply script
# =============================================================================

set -u

WORKER_PORT="${CLAUDE_MEM_WORKER_PORT:-37777}"
CLAUDE_MEM_DIR="${CLAUDE_MEM_DATA_DIR:-$HOME/.claude-mem}"
LOG_FILE="$CLAUDE_MEM_DIR/hook-errors.log"
HEALTH_TIMEOUT=2
START_TIMEOUT=5

# Quick health check - exit 0 immediately if worker is already running
if curl -sf --connect-timeout "$HEALTH_TIMEOUT" --max-time "$HEALTH_TIMEOUT" \
    "http://127.0.0.1:$WORKER_PORT/health" > /dev/null 2>&1; then
    exit 0
fi

# Worker not responding. Try to start it with a short timeout.
CLAUDE_MEM_ROOT="$HOME/.claude/plugins/marketplaces/thedotmack"
BUN="$HOME/.bun/bin/bun"

if [ ! -f "$BUN" ] || [ ! -d "$CLAUDE_MEM_ROOT" ]; then
    exit 0
fi

# Start in background with timeout. If it takes too long, we bail out
# and let the watchdog handle recovery on the next cron cycle.
timeout "$START_TIMEOUT" "$BUN" "$CLAUDE_MEM_ROOT/plugin/scripts/worker-service.cjs" start \
    > /dev/null 2>>"$LOG_FILE" &
START_PID=$!

# Wait for the background start, but only up to START_TIMEOUT seconds
wait "$START_PID" 2>/dev/null

# Always exit 0 - never block the hook pipeline
exit 0
