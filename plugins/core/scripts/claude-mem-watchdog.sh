#!/bin/bash
# =============================================================================
# claude-mem-watchdog.sh - Claude-mem worker health watchdog
# =============================================================================
#
# This script performs a deep health check on the claude-mem worker.
# If the worker is not functioning properly (can't store observations),
# it will restart the worker automatically.
#
# Installation: This script is installed automatically by the plugin installer
# when claude-mem is detected as an enabled plugin.
#
# Cron setup: */30 * * * * ~/.claude-mem/watchdog.sh
# =============================================================================

set -u

CLAUDE_MEM_DIR="${CLAUDE_MEM_DATA_DIR:-$HOME/.claude-mem}"
LOG_FILE="$CLAUDE_MEM_DIR/watchdog.log"
WORKER_PORT="${CLAUDE_MEM_WORKER_PORT:-37777}"
MAX_LOG_SIZE=1048576  # 1MB

# Exit early if claude-mem is not installed
if [ ! -d "$CLAUDE_MEM_DIR" ] || [ ! -f "$CLAUDE_MEM_DIR/cm-hook.sh" ]; then
    exit 0
fi

# Rotate log if too large
if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)" -gt "$MAX_LOG_SIZE" ]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if worker responds to health
health_check() {
    response=$(curl -s --connect-timeout 5 "http://127.0.0.1:$WORKER_PORT/health" 2>/dev/null)
    if [ -z "$response" ]; then
        return 1
    fi
    echo "$response" | grep -q '"status":"ok"'
}

# Check if worker can accept observations (readiness check)
readiness_check() {
    response=$(curl -s --connect-timeout 5 "http://127.0.0.1:$WORKER_PORT/api/readiness" 2>/dev/null)
    if [ -z "$response" ]; then
        return 1
    fi
    echo "$response" | grep -q '"status":"ready"'
}

# Kill existing worker processes
kill_worker() {
    pkill -f "bun.*worker-service.cjs.*--daemon" 2>/dev/null || true
    pkill -f "bun.*worker-service.cjs" 2>/dev/null || true
    sleep 2
}

# Start the worker
start_worker() {
    if [ -f "$CLAUDE_MEM_DIR/cm-hook.sh" ]; then
        "$CLAUDE_MEM_DIR/cm-hook.sh" start > /dev/null 2>&1
        sleep 3
    fi
}

# Main logic
main() {
    # Check health
    if ! health_check; then
        log "WARNING: Worker not responding to health check"
        kill_worker
        start_worker

        if health_check; then
            log "SUCCESS: Worker restarted successfully after health failure"
        else
            log "ERROR: Failed to restart worker after health failure"
        fi
        return
    fi

    # Check readiness
    if ! readiness_check; then
        log "WARNING: Worker not ready (can't process observations)"
        kill_worker
        start_worker

        if readiness_check; then
            log "SUCCESS: Worker restarted successfully after readiness failure"
        else
            log "ERROR: Failed to restart worker after readiness failure"
        fi
        return
    fi

    # All checks passed - only log occasionally to avoid filling the log
    # Log every 6th run (roughly every 3 hours with */30 cron)
    COUNTER_FILE="$CLAUDE_MEM_DIR/.watchdog_counter"
    counter=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
    counter=$((counter + 1))
    if [ "$counter" -ge 6 ]; then
        log "OK: Worker healthy and ready"
        counter=0
    fi
    echo "$counter" > "$COUNTER_FILE"
}

main "$@"
