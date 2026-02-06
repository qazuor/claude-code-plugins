---
name: auto-loop
description: Start an autonomous work loop that processes tasks sequentially with quality gates
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, TaskCreate, TaskUpdate, TaskList, TaskGet
---

# /auto-loop

## Purpose

Start an autonomous loop that processes pending tasks one after another. Each iteration picks the next available task (using /next-task logic), executes it, runs quality gates, and moves to the next task automatically. The loop pauses at phase boundaries and respects guardrails.

## Process

You are the autonomous loop controller for the task-master plugin. Your job is to start a controlled loop that processes tasks sequentially with safety mechanisms.

## Step 1: Validate Prerequisites

Read `.claude/tasks/index.json` and verify there are pending tasks.

If the file does not exist:

```
No tasks found. Use /spec to create a specification or /new-task to create a standalone task.
```

And stop.

Check if a loop is already active by checking for `.claude/auto-loop.local.md`:

```
An auto-loop is already active (iteration X/Y).
Use /auto-loop-cancel to stop it first.
```

And stop.

## Step 2: Configure Loop

Ask the user for configuration:

```
AUTO-LOOP CONFIGURATION
=======================

Max iterations (default 10): ___
Scope:
  (a) Auto - process all available tasks in dependency order (default)
  (b) Select - choose specific task IDs to process

Start autonomous loop? (y/n):
```

**Parameters:**
- `max_iterations`: Maximum number of tasks to process (1-50, default 10)
- `scope`: "auto" or list of specific task IDs
- `completion_promise`: Quality gate requirements (inherited from task-master config)

## Step 3: Show Active Guardrails

Read `.claude/guardrails.md` if it exists and display active guardrails:

```
Active Guardrails:
  GR-001: Verify before complete - run quality gates before marking done
  GR-002: Check all tasks - verify index.json and state.json
  GR-003: Document learnings - update progress/diary at phase end
  GR-004: Small focused changes - max N files per task

Starting loop with 10 max iterations...
```

If no guardrails file exists, show:

```
No guardrails file found. Consider running /setup-project to initialize guardrails.
```

## Step 4: Create State File

Create `.claude/auto-loop.local.md` with YAML frontmatter:

```markdown
---
iteration: 1
max_iterations: 10
scope: auto
task_ids: []
started_at: 2026-02-06T15:00:00Z
current_task: null
completed_tasks: []
completion_promise: quality-gate
---

# Auto-Loop State

This file tracks the autonomous loop state. Delete it to stop the loop.
Do not commit this file (it is local state).
```

## Step 5: Execute Loop Iteration

For each iteration:

### 5a. Read State

Read `.claude/auto-loop.local.md` frontmatter to get current iteration and config.

### 5b. Find Next Task

Use the same logic as /next-task:
- Read `.claude/tasks/index.json` and state files
- Find available tasks (pending, dependencies met, complexity <= 4)
- If scope is specific task IDs, filter to only those
- Select using Quick Win strategy (lowest complexity first)

If no tasks available:

```
AUTO-LOOP COMPLETE
==================

All available tasks have been completed!
Iterations used: X/Y
Tasks completed: [list]
Duration: HH:MM

Cleaning up loop state...
```

Delete the state file and stop.

### 5c. Start Task

```
ITERATION X/Y
==============

Starting: T-XXX "Task title"
Complexity: N/4 | Phase: XXXX
```

Update the task status to in-progress (same as /next-task Step 4b).

### 5d. Execute Task

Work on the task following TDD methodology:
1. RED: Write failing tests
2. GREEN: Write minimum code to pass
3. REFACTOR: Clean up

### 5e. Run Quality Gate

Before marking complete, run the quality gate skill:
- Lint check
- Type check
- Test suite

If quality gate fails, pause the loop:

```
QUALITY GATE FAILED - LOOP PAUSED
==================================

Task: T-XXX "Task title"
Failed: [lint/typecheck/tests]

Fix the issues and resume, or use /auto-loop-cancel to stop.
```

### 5f. Complete Task and Update State

1. Mark task as completed in state.json
2. Update `.claude/auto-loop.local.md`:
   - Increment `iteration`
   - Add task ID to `completed_tasks`
   - Set `current_task` to null

### 5g. Phase Boundary Check

Check if a phase boundary has been crossed (same logic as /next-task Step 5).

If phase boundary crossed, **pause the loop**:

```
PHASE BOUNDARY - LOOP PAUSED
=============================

Phase Complete: CORE
All N core phase tasks are now complete!

Phase progress:
  setup:        2/2 (100%)  DONE
  core:         4/4 (100%)  DONE    <-- just completed
  integration:  0/3 (0%)    next

Continue to next phase? (y/n):
```

Wait for user confirmation before continuing.

### 5h. Check Max Iterations

If `iteration > max_iterations`, stop:

```
AUTO-LOOP: MAX ITERATIONS REACHED
==================================

Completed X tasks in Y iterations.
Tasks completed: [list]

Use /auto-loop to start a new loop for remaining tasks.
```

Delete the state file and stop.

## Step 6: Loop Continuation

After each successful iteration (no pause), immediately proceed to Step 5 for the next iteration. The loop continues until:

1. Max iterations reached
2. No more available tasks
3. Phase boundary crossed (pauses, resumes on confirmation)
4. Quality gate failure (pauses)
5. User cancels with /auto-loop-cancel

## Notes

- The loop ALWAYS pauses at phase boundaries for user review
- Quality gate failures pause but do not cancel the loop
- The state file `.claude/auto-loop.local.md` should NOT be committed (it is ephemeral)
- If the session ends mid-loop, the Stop hook will handle continuation
- Guardrails are checked at the start and enforced throughout
- Each iteration is a complete task cycle: start, implement, test, complete

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Check existence: `[ -d "$DIR" ] && ls "$DIR" 2>/dev/null || echo "(none)"`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
