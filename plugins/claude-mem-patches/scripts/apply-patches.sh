#!/bin/bash
# =============================================================================
# apply-patches.sh - Apply custom patches to claude-mem installation
# =============================================================================
#
# Applies all custom patches to the installed claude-mem plugin:
# 1. Worker auto-restart patch (worker-utils.ts)
# 2. Enhanced watchdog with queue stall detection + stuck message drain
# 3. Fast-fail start guard for hooks (prevents blocking on slow worker)
# 4. Hooks patching (replaces direct bun start with fast guard)
# 5. Crontab setup for watchdog
#
# Usage: bash apply-patches.sh [--dry-run] [--skip-rebuild] [--skip-cron]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
PATCHES_DIR="$PLUGIN_DIR/patches"

CLAUDE_MEM_DIR="$HOME/.claude/plugins/marketplaces/thedotmack"
CLAUDE_MEM_DATA_DIR="${CLAUDE_MEM_DATA_DIR:-$HOME/.claude-mem}"
WATCHDOG_DEST="$CLAUDE_MEM_DATA_DIR/watchdog.sh"

DRY_RUN=false
SKIP_REBUILD=false
SKIP_CRON=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --skip-rebuild) SKIP_REBUILD=true ;;
        --skip-cron) SKIP_CRON=true ;;
        --help|-h)
            echo "Usage: bash apply-patches.sh [--dry-run] [--skip-rebuild] [--skip-cron]"
            echo ""
            echo "Options:"
            echo "  --dry-run       Show what would be done without making changes"
            echo "  --skip-rebuild  Skip the plugin rebuild step"
            echo "  --skip-cron     Skip crontab setup for watchdog"
            exit 0
            ;;
    esac
done

log() {
    echo "[claude-mem-patches] $1"
}

error() {
    echo "[claude-mem-patches] ERROR: $1" >&2
}

# --- Pre-flight checks ---

if [ ! -d "$CLAUDE_MEM_DIR" ]; then
    error "claude-mem not found at $CLAUDE_MEM_DIR"
    error "Install claude-mem first, then run this script."
    exit 1
fi

if [ ! -f "$CLAUDE_MEM_DIR/src/shared/worker-utils.ts" ]; then
    error "worker-utils.ts not found. Is claude-mem installed correctly?"
    exit 1
fi

if ! command -v bun &> /dev/null; then
    error "bun is required but not installed."
    exit 1
fi

# --- Step 1: Apply worker auto-restart patch ---

PATCH_FILE="$PATCHES_DIR/worker-auto-restart.patch"
TARGET_FILE="$CLAUDE_MEM_DIR/src/shared/worker-utils.ts"

log "Step 1: Worker auto-restart patch"

if [ ! -f "$PATCH_FILE" ]; then
    error "Patch file not found: $PATCH_FILE"
    exit 1
fi

# Check if patch is already applied
if grep -q "Auto-restart: try to recover instead of requiring manual intervention" "$TARGET_FILE" 2>/dev/null; then
    log "  Already applied. Skipping."
else
    if [ "$DRY_RUN" = true ]; then
        log "  [DRY RUN] Would apply patch to $TARGET_FILE"
    else
        cd "$CLAUDE_MEM_DIR"
        if git apply --check "$PATCH_FILE" 2>/dev/null; then
            git apply "$PATCH_FILE"
            log "  Applied successfully."
        else
            log "  git apply failed (source may have changed). Trying patch command..."
            if patch --dry-run -p1 < "$PATCH_FILE" > /dev/null 2>&1; then
                patch -p1 < "$PATCH_FILE"
                log "  Applied successfully via patch."
            else
                error "Patch cannot be applied cleanly. claude-mem source may have changed."
                error "You may need to regenerate the patch for the current version."
                exit 1
            fi
        fi
    fi
fi

# --- Step 2: Rebuild plugin ---

if [ "$SKIP_REBUILD" = false ]; then
    log "Step 2: Rebuilding claude-mem plugin"
    if [ "$DRY_RUN" = true ]; then
        log "  [DRY RUN] Would run: npm run build in $CLAUDE_MEM_DIR"
    else
        cd "$CLAUDE_MEM_DIR"
        npm run build 2>&1 | tail -5
        log "  Rebuild complete."
    fi
else
    log "Step 2: Rebuild skipped (--skip-rebuild)"
fi

# --- Step 3: Install enhanced watchdog ---

WATCHDOG_SRC="$PLUGIN_DIR/scripts/watchdog-enhanced.sh"

log "Step 3: Enhanced watchdog"

if [ ! -f "$WATCHDOG_SRC" ]; then
    error "Enhanced watchdog not found: $WATCHDOG_SRC"
    exit 1
fi

mkdir -p "$CLAUDE_MEM_DATA_DIR"

if [ "$DRY_RUN" = true ]; then
    log "  [DRY RUN] Would install watchdog to $WATCHDOG_DEST"
else
    # Backup existing watchdog if it exists and is different
    if [ -f "$WATCHDOG_DEST" ]; then
        if ! diff -q "$WATCHDOG_SRC" "$WATCHDOG_DEST" > /dev/null 2>&1; then
            cp "$WATCHDOG_DEST" "$WATCHDOG_DEST.bak"
            log "  Backed up existing watchdog to watchdog.sh.bak"
        else
            log "  Watchdog already up to date. Skipping."
        fi
    fi
    cp "$WATCHDOG_SRC" "$WATCHDOG_DEST"
    chmod +x "$WATCHDOG_DEST"
    log "  Installed to $WATCHDOG_DEST"
fi

# --- Step 4: Install fast-fail start guard ---

START_GUARD_SRC="$PLUGIN_DIR/scripts/cm-start-guard.sh"
START_GUARD_DEST="$CLAUDE_MEM_DATA_DIR/cm-start-guard.sh"

log "Step 4: Fast-fail start guard"

if [ ! -f "$START_GUARD_SRC" ]; then
    error "Start guard not found: $START_GUARD_SRC"
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    log "  [DRY RUN] Would install start guard to $START_GUARD_DEST"
else
    if [ -f "$START_GUARD_DEST" ] && diff -q "$START_GUARD_SRC" "$START_GUARD_DEST" > /dev/null 2>&1; then
        log "  Start guard already up to date. Skipping."
    else
        cp "$START_GUARD_SRC" "$START_GUARD_DEST"
        chmod +x "$START_GUARD_DEST"
        log "  Installed to $START_GUARD_DEST"
    fi
fi

# --- Step 4b: Patch hooks.json to use start guard ---

log "Step 4b: Hooks patching"

# Find all hooks.json in cache and marketplace
HOOKS_FILES=()
for dir in "$HOME/.claude/plugins/cache/thedotmack/claude-mem"/*/hooks \
           "$CLAUDE_MEM_DIR/plugin/hooks" \
           "$HOME/.claude/plugins/cache/thedotmack/claude-mem"/*/; do
    if [ -f "$dir/hooks.json" ] 2>/dev/null; then
        HOOKS_FILES+=("$dir/hooks.json")
    fi
done

# Also check direct cache path
for hf in "$HOME/.claude/plugins/cache/thedotmack/claude-mem"/*/hooks/hooks.json; do
    [ -f "$hf" ] && HOOKS_FILES+=("$hf")
done

# Deduplicate
mapfile -t HOOKS_FILES < <(printf '%s\n' "${HOOKS_FILES[@]}" | sort -u)

if [ ${#HOOKS_FILES[@]} -eq 0 ]; then
    log "  No hooks.json found to patch. Skipping."
else
    for hooks_file in "${HOOKS_FILES[@]}"; do
        if grep -q "cm-start-guard.sh" "$hooks_file" 2>/dev/null; then
            log "  Already patched: $hooks_file"
            continue
        fi
        if ! grep -q "worker-service.cjs.*start" "$hooks_file" 2>/dev/null; then
            log "  No start commands found in: $hooks_file. Skipping."
            continue
        fi
        if [ "$DRY_RUN" = true ]; then
            log "  [DRY RUN] Would patch: $hooks_file"
        else
            # Use python3 for reliable JSON manipulation
            python3 -c "
import json, sys
guard_path = sys.argv[1]
hooks_path = sys.argv[2]
with open(hooks_path) as f:
    data = json.load(f)
for event_hooks in data.get('hooks', {}).values():
    for group in event_hooks:
        for hook in group.get('hooks', []):
            cmd = hook.get('command', '')
            if 'worker-service.cjs' in cmd and cmd.strip().endswith('start'):
                hook['command'] = guard_path
                hook['timeout'] = 10
with open(hooks_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$START_GUARD_DEST" "$hooks_file"
            log "  Patched: $hooks_file"
        fi
    done
fi

# --- Step 5: Setup crontab ---

if [ "$SKIP_CRON" = false ]; then
    log "Step 5: Crontab setup"
    CRON_ENTRY="*/10 * * * * $WATCHDOG_DEST"

    if crontab -l 2>/dev/null | grep -qF "$WATCHDOG_DEST"; then
        # Check if it's the right frequency
        if crontab -l 2>/dev/null | grep -q "^\*/10.*$WATCHDOG_DEST"; then
            log "  Crontab already configured (*/10). Skipping."
        else
            if [ "$DRY_RUN" = true ]; then
                log "  [DRY RUN] Would update crontab frequency to */10"
            else
                # Remove old entry and add new one
                (crontab -l 2>/dev/null | grep -vF "$WATCHDOG_DEST"; echo "$CRON_ENTRY") | crontab -
                log "  Updated crontab frequency to */10."
            fi
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            log "  [DRY RUN] Would add crontab: $CRON_ENTRY"
        else
            (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
            log "  Added crontab entry."
        fi
    fi
else
    log "Step 5: Crontab setup skipped (--skip-cron)"
fi

# --- Step 6: Restart worker ---

if [ "$SKIP_REBUILD" = false ]; then
    log "Step 6: Restarting worker"
    if [ "$DRY_RUN" = true ]; then
        log "  [DRY RUN] Would restart worker"
    else
        cd "$CLAUDE_MEM_DIR"
        npm run worker:restart 2>&1 | tail -2
        log "  Worker restarted."
    fi
else
    log "Step 6: Worker restart skipped (rebuild was skipped)"
fi

log ""
log "All patches applied successfully."
