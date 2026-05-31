---
name: replan
description: Re-plan tasks when requirements change - add, remove, modify, reorder, or split tasks safely
---

# /replan

## Purpose

Modify task plans when requirements change mid-implementation. Safely add, remove, modify, reorder, or split tasks while preserving completed work and maintaining data consistency.

## Process

You are the task re-planner for the task-master plugin. Your job is to help the user modify their task plan when requirements change mid-implementation, while preserving completed work and maintaining data consistency.

## Input

The user may provide an optional argument:

- **Spec ID** (e.g., `SPEC-001`): re-plan tasks for that specific epic
- **No argument**: ask which epic or standalone group to re-plan

If no argument is provided:

1. Read the tasks index (resolved via `scripts/resolve-paths.sh` as `$TASKS_INDEX`)
2. List available epics and standalone group
3. Ask the user which one to re-plan

If the index file does not exist:

```
No tasks found. Use /spec to create a specification or /new-task to create a standalone task.
```

## Step 1: Show Current State

Read the target `state.json` and present the current state:

```
CURRENT STATE: SPEC-001 "User Authentication"
==============================================

  T-001  Setup auth package structure     setup       COMPLETED   (2)
  T-002  Define user schema               setup       COMPLETED   (3)
  T-003  Create auth middleware            core        IN-PROGRESS (6)
  T-004  Setup Redis cache                core        PENDING     (4)
  T-005  Implement OAuth callback          core        PENDING     (5)
  T-006  Add session management            core        BLOCKED     (7)
  T-007  Write login page tests            testing     COMPLETED   (2)
  T-008  Integration tests                 testing     BLOCKED     (8)
  T-009  Write API docs                    docs        PENDING     (2)
  T-010  Update README                     docs        PENDING     (1)

  Summary: 10 tasks | 3 completed | 1 in-progress | 4 pending | 2 blocked
  Dependencies: T-003 blocks [T-005, T-006]; T-004 blocks [T-006]; T-005,T-006 block [T-008]

  NOTE: Completed tasks (T-001, T-002, T-007) cannot be modified.
```

## Step 2: Present Modification Options

```
What would you like to change?

  (1) Add new tasks
  (2) Remove/cancel pending tasks
  (3) Modify existing task details (description, complexity, tags, phase)
  (4) Reorder dependencies
  (5) Split a task into subtasks
  (6) Done - apply changes and exit

Enter option number (or multiple separated by commas):
```

The user can perform multiple operations in sequence. After each operation, show the updated state and present the options again until the user chooses (6).

## Option 1: Add New Tasks

### Flow

1. Ask for task details (same fields as `/new-task`):
   - Title (required)
   - Description (optional)
   - Complexity (1-10)
   - Tags
   - Phase
   - Blocked by (existing task IDs)
   - Blocks (existing task IDs)

2. Generate next task ID:
   - Find the highest existing task ID across ALL state files (not just the current one)
   - New ID = highest + 1, zero-padded to 3 digits

3. Add the task to the `tasks` array in state.json

4. If the new task `blocks` existing tasks, update those tasks' `blockedBy` arrays to include the new task ID

5. If the new task is `blockedBy` existing tasks, update those tasks' `blocks` arrays to include the new task ID

6. Show the new task and its position in the dependency graph

## Option 2: Remove/Cancel Tasks

### Rules

- **NEVER modify or remove completed tasks** -- they represent finished work
- **NEVER modify or remove in-progress tasks** without explicit user confirmation
- Only `pending` and `blocked` tasks can be cancelled freely

### Flow

1. Show list of removable tasks (non-completed, non-in-progress)
2. Ask user which task(s) to cancel (by ID)
3. For each cancelled task:
   - Set its `status` to `"cancelled"`
   - Set `timestamps.completed` to current timestamp (as cancellation time)
   - Remove its ID from all other tasks' `blockedBy` arrays
   - Remove its ID from all other tasks' `blocks` arrays
   - Check if removing blockedBy entries unblocks any tasks -- update their status from `"blocked"` to `"pending"` if all blockedBy are now completed or cancelled
4. Show which tasks were unblocked by the cancellation

### In-progress task warning

If the user tries to cancel an in-progress task:

```
WARNING: T-003 is currently in-progress (started 2025-01-13T08:00:00Z).
Cancelling will discard any work done on this task.

Are you sure? (yes/no)
```

## Option 3: Modify Existing Tasks

### Rules

- **NEVER modify completed tasks**
- Can modify: `title`, `description`, `complexity`, `tags`, `phase`
- Cannot modify directly: `status`, `blockedBy`, `blocks` (use other options for these)
- Cannot modify: `id`, `timestamps.created`

### Flow

1. Ask which task to modify (by ID)
2. Show current values
3. Ask which fields to change
4. Apply changes
5. If complexity changed, recalculate `summary.averageComplexity`

### Complexity Validation

**Maximum complexity for atomic tasks is 3.** If the user sets complexity > 3:

```
⚠ WARNING: Complexity {value} exceeds the maximum of 3 for atomic tasks.

Tasks with complexity > 3 cannot be started and will be blocked by the quality gate.
Options:
  (a) Keep complexity {value} — task will be flagged for splitting via /replan
  (b) Set complexity to 3 — accept as-is at the ceiling
  (c) Split this task now — decompose into smaller tasks (recommended)

Choose an option:
```

If the user chooses (c), transition to Option 5 (Split) for that task.

## Option 4: Reorder Dependencies

### Flow

1. Show current dependency graph (same format as `/task-status`)
2. Ask what to change:
   - Add a dependency: "T-005 should be blocked by T-004"
   - Remove a dependency: "T-006 no longer needs T-004"
3. Apply the change to both the `blockedBy` and `blocks` arrays of the affected tasks

### Circular Dependency Detection

**CRITICAL**: After any dependency change, run circular dependency detection.

Algorithm (DFS-based):

```
function hasCycle(tasks):
  for each task in tasks:
    visited = {}
    stack = {}
    if dfs(task, visited, stack, tasks):
      return the cycle path

function dfs(task, visited, stack, tasks):
  if task.id in stack:
    return true  // cycle detected
  if task.id in visited:
    return false
  visited[task.id] = true
  stack[task.id] = true
  for each blockedId in task.blockedBy:
    blocker = findTask(blockedId, tasks)
    if dfs(blocker, visited, stack, tasks):
      return true
  delete stack[task.id]
  return false
```

If a circular dependency is detected:

```
ERROR: Circular dependency detected!

  T-003 --> T-005 --> T-008 --> T-003

This would create a deadlock where no task can proceed.
The dependency change has been REJECTED. Please try a different arrangement.
```

Reject the change and re-prompt.

### Status updates after dependency changes

After modifying dependencies:
- Check if any `blocked` tasks now have all their `blockedBy` tasks completed/cancelled -- change them to `pending`
- Check if any `pending` tasks now have incomplete `blockedBy` tasks -- change them to `blocked`

## Option 5: Split a Task into Subtasks

### Flow

1. Ask which task to split (by ID)
2. The task must NOT be completed
3. Show current task details
4. Ask how many subtasks to create
5. For each subtask, gather: title, completed (boolean)
6. Replace the task's `subtasks` array with the new subtask objects:

```json
{
  "title": "Define middleware function signature",
  "completed": false
}
```

Note: Subtasks are lightweight checklists within a task. They do NOT create new task IDs or have their own state. For creating fully independent tasks, use Option 1 instead.

If the user wants to split a task into multiple independent tasks:
1. Create new tasks (Option 1) for each piece
2. Transfer the original task's dependencies to the new tasks appropriately
3. Cancel the original task (Option 2)
4. Score the new tasks using the complexity-scorer criteria
5. **If any new task has complexity > 3**, warn the user and offer to split further:
   ```
   ⚠ New task T-013 has complexity 5 (max: 3). Split further? (yes/no)
   ```
6. Repeat splitting until all resulting tasks have complexity ≤ 3 or the user explicitly accepts
7. Walk the user through this process step by step

## Step 3: Apply Changes

After the user chooses option (6) to finish:

### 3-PRE. Progress Preservation (MANDATORY — run BEFORE any write)

Before touching `state.json`, snapshot every task whose `status` is `"completed"` into an
immutable preservation set. These records must survive the replan byte-for-byte.

```bash
# Extract completed tasks from the current state.json (inside the flock block, before any write)
COMPLETED_SNAPSHOT=$(jq '[.tasks[] | select(.status == "completed")]' "$STATE_FILE")
```

After the new task list is computed (adds, cancels, modifications, splits), re-embed every record
from `COMPLETED_SNAPSHOT` verbatim into the new task list. Re-embedding rules:

1. Match by `id`. If a completed task ID already appears in the new task list (e.g., it was
   inadvertently carried forward), replace it with the snapshot record.
2. If a completed task ID does NOT appear in the new task list, insert the snapshot record as-is.
3. **Never modify any field** of a completed task record during re-embedding — not `timestamps`,
   not `qualityGate` results, not `subtasks`, not `commit` refs. Completed = immutable.
4. After re-embedding, verify that `jq '[.tasks[] | select(.status == "completed")] | length'`
   on the new state equals `COMPLETED_SNAPSHOT | length`. If the count is lower, abort and report
   the discrepancy to the user before writing.

**Completed work must survive replan byte-for-byte.** Replan reorganises pending and future work;
it never erases what has already been done.

### 3a. Recompute summary statistics

Recalculate the `summary` object in `state.json`:

- `total`: count all non-cancelled tasks (or count all tasks -- be consistent with initial creation)
- `pending`: count tasks with status `"pending"`
- `inProgress`: count tasks with status `"in-progress"`
- `completed`: count tasks with status `"completed"`
- `blocked`: count tasks with status `"blocked"`
- `averageComplexity`: average complexity of non-completed, non-cancelled tasks

### 3b. Update state.json

Write the updated state back to the state file.

### 3c. Regenerate TODOs.md

Regenerate the TODOs.md file from the current state. Format:

```markdown
# TODOs: [Title]

Spec: SPEC-NNN | Status: in-progress | Progress: completed/total

## Setup

- [x] T-001: Setup auth package structure (complexity: 2)
- [x] T-002: Define user schema (complexity: 3)

## Core

- [ ] T-003: Create auth middleware (complexity: 6) [in-progress]
- [ ] T-004: Setup Redis cache (complexity: 4)
- [ ] T-005: Implement OAuth callback (complexity: 5) [blocked by T-003]
- [ ] T-006: Add session management (complexity: 7) [blocked by T-003, T-004]
- [ ] T-011: New validation layer (complexity: 4) [NEW]

## Testing

- [x] T-007: Write login page tests (complexity: 2)
- [ ] T-008: Integration tests (complexity: 8) [blocked by T-005, T-006]

## Docs

- [ ] T-009: Write API docs (complexity: 2)
- [ ] T-010: Update README (complexity: 1)

## Cancelled

- ~~T-012: Removed feature~~ (cancelled)
```

Rules for TODOs.md:
- Use `[x]` for completed tasks
- Use `[ ]` for all other active tasks
- Show `[in-progress]` for in-progress tasks
- Show `[blocked by ...]` for blocked tasks
- Show `[NEW]` for newly added tasks (added during this replan session)
- Show cancelled tasks in a separate section at the bottom with strikethrough
- Include progress summary at the top

### 3d. Update task index

Use the **index-sync skill** to update both the tasks index and the specs index (resolved via `scripts/resolve-paths.sh`) atomically.  NEVER write one index alone.

Wrap the state.json write AND the index-sync call in a single `flock` block:

```bash
eval "$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-paths.sh")"

(
  flock -w 10 200 || { echo "index busy, another session holds the lock — retry in a moment"; exit 1; }

  # Write the updated state.json first (inside the lock)
  jq ... "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

  # Then call index-sync for both indexes (index-sync reuses the same lock file,
  # so pass the already-acquired fd or call its jq writes directly here)
  # Provide: specId, newStatus (if status changed), newProgress ("completed/total")

) 200>"$LOCK"
```

Inputs to index-sync:
- `specId`: the spec being replanned
- `newStatus`: new epic status if it changed (e.g., tasks added that change `completed` → `in-progress`), or `null` if unchanged
- `newProgress`: updated `"N/M"` string reflecting the new total after adds/cancels

Standalone counts: if replanning the standalone group, update `standalone.total` and `standalone.completed` in `tasks/index.json` directly within the same `flock` block.

### 3e. Show diff

Present a summary of all changes made:

```
REPLAN COMPLETE: SPEC-001 "User Authentication"
================================================

Changes applied:

  ADDED:
    + T-011 "New validation layer" (core, complexity: 4)
      Blocked by: T-003

  CANCELLED:
    - T-012 "Removed feature" (was: pending)
      Unblocked: T-008 (was blocked by T-012)

  MODIFIED:
    ~ T-004 complexity: 4 -> 6
    ~ T-004 description: updated

  DEPENDENCIES CHANGED:
    ~ T-005 now blocked by: T-003, T-011 (was: T-003)

  SUMMARY BEFORE:  10 tasks | 3 done | 1 wip | 4 pending | 2 blocked
  SUMMARY AFTER:   11 tasks | 3 done | 1 wip | 4 pending | 3 blocked

  Files updated:
    <tasks-dir>/SPEC-001-user-auth/state.json
    <tasks-dir>/SPEC-001-user-auth/TODOs.md
    <tasks-dir>/index.json
```

## Safety Rules

1. **NEVER modify completed tasks** -- they represent finished, committed work
2. **NEVER delete task data** -- cancelled tasks remain in state with `"cancelled"` status
3. **ALWAYS snapshot completed tasks BEFORE any write** (Step 3-PRE) and re-embed them verbatim
   after the new plan is computed -- completed work must survive replan byte-for-byte
4. **ALWAYS verify completed-task count** after re-embedding matches the pre-replan snapshot count
   before writing; abort and report if any completed record went missing
5. **ALWAYS check for circular dependencies** after any dependency modification
6. **ALWAYS update both sides** of a dependency (blockedBy AND blocks)
7. **ALWAYS recalculate summary** after any changes
8. **ALWAYS regenerate TODOs.md** to keep it in sync with state.json
9. **ALWAYS show the diff** so the user can verify changes
10. **ALWAYS ask for confirmation** before applying destructive changes (cancellation)

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Create with `mkdir -p` and check with `[ -d "$DIR" ]`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
- **Index writes**: ALWAYS update both indexes via the `index-sync` skill (Step 3d).  NEVER write one index alone.
- **Locking**: ALL index/state mutations in Step 3 MUST happen inside a single `flock` block on `$LOCK` (resolved via `scripts/resolve-paths.sh`) with a 10-second timeout.  This prevents concurrent replan sessions from corrupting the indexes.
