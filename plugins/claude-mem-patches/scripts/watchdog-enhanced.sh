#!/bin/bash
# =============================================================================
# watchdog-enhanced.sh - Claude-mem worker health watchdog (enhanced)
# =============================================================================
#
# Enhanced version of the basic watchdog with:
# - Queue stall detection (queue depth + memorySessionId errors)
# - Stuck message drain before restart (TTL + max retries)
# - Restart cooldown to prevent restart loops
# - Cross-platform stat compatibility (Linux + macOS)
# - Periodic OK logging (every ~3 hours) to avoid log bloat
#
# Installation: Installed by claude-mem-patches apply script
# Cron setup: */10 * * * * ~/.claude-mem/watchdog.sh
# =============================================================================

set -u

CLAUDE_MEM_DIR="${CLAUDE_MEM_DATA_DIR:-$HOME/.claude-mem}"
LOG_FILE="$CLAUDE_MEM_DIR/watchdog.log"
WORKER_PORT="${CLAUDE_MEM_WORKER_PORT:-37777}"
MAX_LOG_SIZE=1048576  # 1MB

# Stalled queue detection thresholds
QUEUE_DEPTH_THRESHOLD=200           # Restart if queue exceeds this
STALL_ERROR_THRESHOLD=50            # Restart if "memorySessionId not yet captured" errors exceed this in recent log
STALL_CHECK_LINES=2000              # Number of recent log lines to scan for stall detection
QUEUE_SNAPSHOT_FILE="$CLAUDE_MEM_DIR/.watchdog_queue_snapshot"
LAST_RESTART_FILE="$CLAUDE_MEM_DIR/.watchdog_last_restart"
RESTART_COOLDOWN=600                # 10 minutes cooldown between restarts

# Stuck message cleanup thresholds
PENDING_TTL_SECONDS=7200            # Delete pending messages older than 2 hours
PENDING_MAX_RETRIES=3               # Delete pending messages after 3 failed retries
DB_FILE="$CLAUDE_MEM_DIR/claude-mem.db"

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

# Get current queue depth from worker status endpoint
get_queue_depth() {
    response=$(curl -s --connect-timeout 5 "http://127.0.0.1:$WORKER_PORT/api/status" 2>/dev/null)
    if [ -z "$response" ]; then
        echo "-1"
        return
    fi
    # Try to extract queueDepth from JSON response
    depth=$(echo "$response" | grep -oP '"queueDepth"\s*:\s*\K[0-9]+' 2>/dev/null || echo "")
    if [ -z "$depth" ]; then
        # Fallback: parse from recent log
        depth=$(tail -100 "$CLAUDE_MEM_DIR/logs/claude-mem-$(date '+%Y-%m-%d').log" 2>/dev/null \
            | grep -oP 'queueDepth=\K[0-9]+' | tail -1)
    fi
    echo "${depth:-0}"
}

# Count "memorySessionId not yet captured" errors in recent log lines
count_stall_errors() {
    today_log="$CLAUDE_MEM_DIR/logs/claude-mem-$(date '+%Y-%m-%d').log"
    if [ ! -f "$today_log" ]; then
        echo "0"
        return
    fi
    tail -"$STALL_CHECK_LINES" "$today_log" 2>/dev/null \
        | grep -c "memorySessionId not yet captured" 2>/dev/null || echo "0"
}

# Check if queue is stalled (growing or not draining, with persistent errors)
queue_stall_check() {
    current_depth=$(get_queue_depth)
    stall_errors=$(count_stall_errors)
    prev_depth=$(cat "$QUEUE_SNAPSHOT_FILE" 2>/dev/null || echo "0")

    # Save current depth for next run comparison
    echo "$current_depth" > "$QUEUE_SNAPSHOT_FILE"

    # Check 1: Queue depth exceeds absolute threshold
    if [ "$current_depth" -gt "$QUEUE_DEPTH_THRESHOLD" ]; then
        log "STALL DETECTED: Queue depth $current_depth exceeds threshold $QUEUE_DEPTH_THRESHOLD (stall errors: $stall_errors)"
        return 0
    fi

    # Check 2: High number of memorySessionId errors (sessions stuck without init)
    if [ "$stall_errors" -gt "$STALL_ERROR_THRESHOLD" ]; then
        # Only trigger if queue is also not draining (growing or stable)
        if [ "$current_depth" -ge "$prev_depth" ] && [ "$current_depth" -gt 0 ]; then
            log "STALL DETECTED: $stall_errors memorySessionId errors in recent log, queue not draining ($prev_depth -> $current_depth)"
            return 0
        fi
    fi

    return 1
}

# Drain stuck pending messages from the queue before restart.
# This prevents the crash loop where the worker endlessly retries
# unprocessable messages from dead sessions.
# Strategy: TTL (>2h old = delete) + max retries (>=3 = delete, else increment)
drain_stuck_messages() {
    if ! command -v sqlite3 &> /dev/null; then
        log "DRAIN: sqlite3 not found, skipping queue cleanup"
        return
    fi
    if [ ! -f "$DB_FILE" ]; then
        log "DRAIN: database not found, skipping queue cleanup"
        return
    fi

    local now_epoch
    now_epoch=$(date +%s)
    local cutoff_epoch=$((now_epoch - PENDING_TTL_SECONDS))

    # Count messages before cleanup
    local total_pending
    total_pending=$(sqlite3 "$DB_FILE" "SELECT count(*) FROM pending_messages WHERE status = 'pending';" 2>/dev/null || echo "0")

    if [ "$total_pending" -eq 0 ]; then
        return
    fi

    # Step 1: Delete messages older than TTL (2 hours)
    local expired_count
    expired_count=$(sqlite3 "$DB_FILE" "SELECT count(*) FROM pending_messages WHERE status = 'pending' AND created_at_epoch < $cutoff_epoch;" 2>/dev/null || echo "0")
    if [ "$expired_count" -gt 0 ]; then
        sqlite3 "$DB_FILE" "DELETE FROM pending_messages WHERE status = 'pending' AND created_at_epoch < $cutoff_epoch;" 2>/dev/null
        log "DRAIN: Deleted $expired_count expired messages (older than ${PENDING_TTL_SECONDS}s)"
    fi

    # Step 2: Increment retry_count for remaining pending messages
    sqlite3 "$DB_FILE" "UPDATE pending_messages SET retry_count = retry_count + 1 WHERE status = 'pending';" 2>/dev/null

    # Step 3: Delete messages that exceeded max retries
    local retried_count
    retried_count=$(sqlite3 "$DB_FILE" "SELECT count(*) FROM pending_messages WHERE status = 'pending' AND retry_count >= $PENDING_MAX_RETRIES;" 2>/dev/null || echo "0")
    if [ "$retried_count" -gt 0 ]; then
        sqlite3 "$DB_FILE" "DELETE FROM pending_messages WHERE status = 'pending' AND retry_count >= $PENDING_MAX_RETRIES;" 2>/dev/null
        log "DRAIN: Deleted $retried_count messages exceeding max retries ($PENDING_MAX_RETRIES)"
    fi

    # Log summary
    local remaining
    remaining=$(sqlite3 "$DB_FILE" "SELECT count(*) FROM pending_messages WHERE status = 'pending';" 2>/dev/null || echo "0")
    local cleaned=$((total_pending - remaining))
    if [ "$cleaned" -gt 0 ]; then
        log "DRAIN: Cleaned $cleaned/$total_pending stuck messages ($remaining remaining)"
    fi
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

# Check if we restarted recently (prevent restart loops)
is_in_cooldown() {
    if [ ! -f "$LAST_RESTART_FILE" ]; then
        return 1
    fi
    last_restart=$(cat "$LAST_RESTART_FILE" 2>/dev/null || echo "0")
    now=$(date +%s)
    elapsed=$((now - last_restart))
    if [ "$elapsed" -lt "$RESTART_COOLDOWN" ]; then
        return 0
    fi
    return 1
}

restart_worker() {
    local reason="$1"

    if is_in_cooldown; then
        log "SKIPPED RESTART: cooldown active (reason: $reason)"
        return
    fi

    log "RESTARTING: $reason"
    date +%s > "$LAST_RESTART_FILE"
    drain_stuck_messages
    kill_worker
    start_worker

    if health_check && readiness_check; then
        # Reset stall snapshot after successful restart
        echo "0" > "$QUEUE_SNAPSHOT_FILE"
        log "SUCCESS: Worker restarted successfully ($reason)"
    else
        log "ERROR: Failed to restart worker ($reason)"
    fi
}

# Main logic
main() {
    # Check health
    if ! health_check; then
        restart_worker "worker not responding to health check"
        return
    fi

    # Check readiness
    if ! readiness_check; then
        restart_worker "worker not ready (can't process observations)"
        return
    fi

    # Check for stalled queue (worker is "healthy" but observations are stuck)
    if queue_stall_check; then
        restart_worker "stalled queue with unprocessable observations"
        return
    fi

    # All checks passed - only log occasionally to avoid filling the log
    # Log every 18th run (roughly every 3 hours with */10 cron)
    COUNTER_FILE="$CLAUDE_MEM_DIR/.watchdog_counter"
    counter=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
    counter=$((counter + 1))
    if [ "$counter" -ge 18 ]; then
        current_depth=$(get_queue_depth)
        log "OK: Worker healthy and ready (queueDepth=$current_depth)"
        counter=0
    fi
    echo "$counter" > "$COUNTER_FILE"
}

main "$@"
