---
name: next-task
description: Find and start the next available task based on dependencies and complexity
---

# /next-task

## Purpose

Find the next available task based on dependency resolution and complexity scoring, present it with full details, and start it upon user confirmation.

## Process

You are the task selector for the task-master plugin. Your job is to find the next available task the user can work on, present it with full details, and start it upon confirmation.

## Step 1: Read Task Data

Read `.claude/tasks/index.json` to get the list of all epics and standalone task info.

If the file does not exist:

```
No tasks found. Use /spec to create a specification or /new-task to create a standalone task.
```

And stop.

For each epic in the `epics` array, read `.claude/tasks/{path}/state.json`.

If standalone tasks exist (`standalone.total > 0`), read `.claude/tasks/{standalone.path}/state.json`.

## Step 2: Compute Available Tasks

A task is **available** if ALL of the following are true:

1. Its `status` is `"pending"` (not in-progress, completed, blocked, or cancelled)
2. Its `blockedBy` array is empty, OR every task ID in `blockedBy` has status `"completed"` in the same state file
3. Its `complexity` is ≤ 3 (tasks with complexity > 3 are too complex and must be split first)

Collect all available tasks from all state files. Track which epic/standalone group each task belongs to.

### Complexity Filter

**Tasks with complexity > 3 are NEVER presented as available**, even if they meet all other criteria. Instead, they are listed separately with a warning:

```
⚠ Tasks requiring decomposition (complexity > 3):

  T-009 "Implement full OAuth flow" (complexity: 6)
    This task exceeds the maximum complexity of 3 and cannot be started.
    Use /replan to split it into smaller tasks first.

  T-012 "Build admin dashboard" (complexity: 5)
    This task exceeds the maximum complexity of 3 and cannot be started.
    Use /replan to split it into smaller tasks first.
```

This acts as a safety net to prevent execution of tasks that slipped through the multi-pass decomposition.

### Handle edge cases

- **No tasks at all**: Display "No tasks found" message
- **All tasks completed**: Display congratulations message with completion stats
- **All remaining tasks blocked**: Display "All remaining tasks are blocked" with details of what's blocking progress and which in-progress tasks need to finish first
- **All available tasks exceed complexity 3**: Display "All available tasks exceed maximum complexity 3. Use /replan to split them before continuing."
- **Tasks already in-progress**: Remind the user they have in-progress tasks and ask if they want to continue those first before starting a new one

## Step 3: Rank Available Tasks

Rank available tasks using two strategies and present both:

### Strategy A: Quick Win (lowest complexity first)

Sort available tasks by:
1. `complexity` ascending (lowest first)
2. Tie-breaker: phase order (`setup` > `core` > `integration` > `testing` > `docs` > `cleanup`)
3. Tie-breaker: task ID ascending

### Strategy B: Critical Path (unblocks the most work)

For each available task, count how many other tasks it transitively unblocks:
1. Direct: count tasks whose `blockedBy` contains this task's ID
2. Transitive: for each directly unblocked task, count what THAT task unblocks, recursively
3. Sort by total transitive unblock count, descending
4. Tie-breaker: complexity ascending

### Present both options

```
NEXT AVAILABLE TASKS
====================

Strategy A: Quick Win (fastest to complete)
-------------------------------------------

  [1] T-007 "Write login page unit tests"
      Epic: SPEC-001 "User Authentication"
      Complexity: 2/10 | Phase: testing | Tags: frontend, testing
      Description: Write unit tests for the login page component
        covering form validation, submission, and error states.
      Blocked by: none
      Unblocks: T-009

Strategy B: Critical Path (unblocks the most work)
---------------------------------------------------

  [1] T-003 "Create auth middleware"
      Epic: SPEC-001 "User Authentication"
      Complexity: 6/10 | Phase: core | Tags: backend, security
      Description: Implement Express middleware for JWT token
        validation and role-based access control.
      Blocked by: none
      Unblocks: T-005, T-006, T-008 (+ 2 transitive)

Also available: 3 more tasks (use /tasks for full dashboard)

Currently in-progress: none

Which task would you like to start? Enter the task ID (e.g., T-007) or [skip]:
```

## Step 3.5: Spec Realign Gate (first task of a spec this session)

Before starting any task, check whether this is the **first task being started for its parent spec in this session**.

**How to detect "first task of the spec this session":**
- Look at the selected task's parent epic (its `specId` in index.json)
- Check whether any other task in that same epic has `status: "in-progress"` — if yes, the spec is already underway this session, skip the gate
- If no task in the epic is currently `in-progress`, this is the first task for that spec this session → trigger the gate

**Gate prompt (show only when triggered):**

```
Spec drift check: SPEC-NNN "Spec Title"
----------------------------------------
This spec may have drifted from the codebase since it was written
(other specs or refactors may have changed things it depends on).

Run /spec-realign before starting? (yes / skip):
```

- If the user answers **yes**: stop here and invoke `/spec-realign SPEC-NNN`. Do NOT proceed to Step 4 until the realign command finishes.
- If the user answers **skip** (or any variation of no/n/skip): proceed directly to Step 4 without comment.
- The gate appears at most ONCE per spec per session. If the user skips, do not re-ask for subsequent tasks of the same spec in the same session. Track which spec IDs have had the gate shown this session (in memory, not in any file).

## Step 4: Confirm and Start Task

When the user selects a task (by ID or by choosing option 1/2):

### 4a. Validate selection

Ensure the selected task ID exists and is actually available (status pending, dependencies met). If not, explain why and re-prompt.

### 4b. Update task status

In the appropriate `state.json` file, wrap ALL reads and writes in a single `flock` block to prevent a parallel `/next-task` session from picking the same task:

```bash
(
  flock -w 10 200 || { echo "index busy, another session holds the lock — retry in a moment"; exit 1; }

  # 1. Re-read state.json inside the lock to confirm task is still "pending"
  #    (another session may have claimed it between Step 2 and now)
  CURRENT_STATUS=$(jq -r --arg id "$taskId" '.tasks[] | select(.id == $id) | .status' "$STATE_FILE" 2>/dev/null)
  if [ "$CURRENT_STATUS" != "pending" ]; then
    echo "Task $taskId is no longer pending (status: $CURRENT_STATUS) — another session may have claimed it. Re-run /next-task."
    exit 1
  fi

  # 2. Apply the mutations inside the lock
  jq --arg id "$taskId" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    .tasks |= map(
      if .id == $id then
        .status = "in-progress" |
        .timestamps.started = $ts
      else . end
    ) |
    .summary.pending   -= 1 |
    .summary.inProgress += 1
  ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

) 200>.claude/tasks/.index.lock
```

### 4c. Update task index

Use the **index-sync skill** to update both `.claude/specs/index.json` and `.claude/tasks/index.json` atomically.  NEVER write one index alone.

- For epic tasks: if the epic's current status is `"pending"`, pass `newStatus: "in-progress"` to index-sync.
- The index-sync skill wraps its writes in the same `flock` block — no double-locking needed.
- For standalone tasks: no index status update needed (counts live in state.json), but still confirm the tasks/index.json standalone counts remain accurate.

```
Call index-sync with:
  specId:       <parent specId from index.json>
  newStatus:    "in-progress"   (only if current epic status is "pending")
  newProgress:  null            (progress is derived from state.json, not set here)
```

### 4d. Confirm to user

```
Task started!

  T-003 "Create auth middleware"
  Status: in-progress
  Started: 2025-01-15T10:30:00Z

  Description:
  Implement Express middleware for JWT token validation
  and role-based access control.

  Subtasks:
  - [ ] Define middleware function signature
  - [ ] Implement JWT verification
  - [ ] Add role checking logic
  - [ ] Handle expired tokens
  - [ ] Write error responses

  When finished, the task will need to pass quality gates:
  - Lint check
  - Type check
  - Test suite

  Good luck! The quality gate (lint, typecheck, tests) will run before completion.
```

Show the task's subtasks (if any) as a checklist to guide implementation.

**Always remind the user to follow TDD:**

```
Development approach: TDD (Red-Green-Refactor)
  1. RED:      Write failing tests first (based on task test requirements)
  2. GREEN:    Write minimum code to make tests pass
  3. REFACTOR: Improve code while tests stay green

Remember: No tests = not done. Implementation and tests are committed together.
```

## Step 5: Phase Boundary Check

After the user completes a task and before suggesting the next one, check if a **phase boundary** has been crossed.

A phase boundary is crossed when:
- The completed task was the last remaining task in its phase (all tasks in that phase are now `completed`)
- The next available task belongs to a different phase

When a phase boundary is crossed:

```
Phase Complete: CORE
====================

All 4 core phase tasks are now complete!

  Phase progress:
    setup:        2/2 (100%)  DONE
    core:         4/4 (100%)  DONE    <-- just completed
    integration:  0/3 (0%)    next
    testing:      0/2 (0%)
    docs:         0/1 (0%)

  Overall: 6/12 tasks (50%)

The next tasks are in the INTEGRATION phase.
Would you like to:
  (a) Continue to the integration phase
  (b) Review completed work first
  (c) Stop here for now
```

**Always pause at phase boundaries.** This gives the user a natural checkpoint to review progress, adjust course, or take a break before continuing.

## Step 6: Remind About State Updates

After each task is completed, remind the user:

```
Remember: Task state has been updated.
  - T-003 status: completed
  - Quality gate: lint(pass) typecheck(pass) tests(pass)
  - Progress: 6/12 (50%)
  - Commit your changes with /commit before starting the next task.
```

**State updates are mandatory.** The task dashboard, next-task selection, and phase tracking all depend on accurate, up-to-date state.

## Notes

- Never auto-start a task without user confirmation
- If the user has in-progress tasks, always mention them before suggesting new ones
- The quick win strategy helps maintain momentum; the critical path strategy helps when the project needs to move forward fastest
- Always show the task description in full so the user knows exactly what to work on
- **Always check for phase boundaries** when suggesting the next task
- **Always update task state** after completion — never skip this step
- **Always remind the user to commit** after completing a task

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Check existence: `[ -d "$DIR" ] && ls "$DIR" 2>/dev/null || echo "(none)"`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
- **Index writes**: ALWAYS update both indexes via the `index-sync` skill.  NEVER write one index alone.
- **Locking**: ALL index/state mutations (Steps 4b and 4c) MUST happen inside a single `flock` block on `.claude/tasks/.index.lock` with a 10-second timeout.  This prevents two parallel worktrees from claiming the same task simultaneously.
