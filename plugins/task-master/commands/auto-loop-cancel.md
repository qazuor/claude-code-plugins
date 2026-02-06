---
name: auto-loop-cancel
description: Cancel an active autonomous work loop and show summary
allowed-tools: Read, Bash, Glob
---

# /auto-loop-cancel

## Purpose

Stop an active autonomous loop started by /auto-loop. Shows a summary of work completed and cleans up the state file.

## Process

You are the loop cancellation handler for the task-master plugin. Your job is to safely stop an active loop and report what was accomplished.

## Step 1: Check for Active Loop

Check if `.claude/auto-loop.local.md` exists.

If the file does not exist:

```
No active auto-loop found. Nothing to cancel.
```

And stop.

## Step 2: Read Loop State

Parse the YAML frontmatter from `.claude/auto-loop.local.md`:

- `iteration`: Current iteration number
- `max_iterations`: Maximum configured iterations
- `started_at`: When the loop started
- `completed_tasks`: List of task IDs completed
- `current_task`: Task currently in progress (may be null)

## Step 3: Handle In-Progress Task

If `current_task` is not null, warn the user:

```
WARNING: Task T-XXX is currently in progress.
Cancelling the loop will NOT revert this task to pending.
You can continue working on it manually.
```

## Step 4: Show Summary

```
AUTO-LOOP CANCELLED
===================

Started: 2026-02-06T15:00:00Z
Iterations: X/Y
Tasks completed: N

Completed tasks:
  - T-001 "Task title 1"
  - T-003 "Task title 2"
  - T-007 "Task title 3"

Current task (in-progress): T-009 "Task title 4"

Loop state file removed.
Use /tasks for full dashboard.
```

## Step 5: Clean Up

Delete `.claude/auto-loop.local.md`.

## Notes

- Cancelling the loop does NOT revert any completed tasks
- Any in-progress task remains in-progress
- The user can restart a loop at any time with /auto-loop

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
