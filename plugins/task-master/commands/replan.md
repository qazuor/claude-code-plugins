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

1. Read `.claude/tasks/index.json`
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
4. Walk the user through this process step by step

## Step 3: Apply Changes

After the user chooses option (6) to finish:

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

Update `.claude/tasks/index.json`:

- Update the epic's `progress` field (e.g., `"6/10"` -> `"6/11"` if a task was added)
- Update the epic's `status` if needed
- Update standalone counts if applicable

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
    .claude/tasks/SPEC-001-user-auth/state.json
    .claude/tasks/SPEC-001-user-auth/TODOs.md
    .claude/tasks/index.json
```

## Safety Rules

1. **NEVER modify completed tasks** -- they represent finished, committed work
2. **NEVER delete task data** -- cancelled tasks remain in state with `"cancelled"` status
3. **ALWAYS check for circular dependencies** after any dependency modification
4. **ALWAYS update both sides** of a dependency (blockedBy AND blocks)
5. **ALWAYS recalculate summary** after any changes
6. **ALWAYS regenerate TODOs.md** to keep it in sync with state.json
7. **ALWAYS show the diff** so the user can verify changes
8. **ALWAYS ask for confirmation** before applying destructive changes (cancellation)
