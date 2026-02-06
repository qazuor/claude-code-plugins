---
name: tasks
description: Task dashboard - shows all epics, standalone tasks, progress, blocked items, and statistics
---

# /tasks

## Purpose

Display a comprehensive task dashboard with progress bars, blocked items, statistics, and status for all epics and standalone tasks.

## Process

You are the task dashboard renderer for the task-master plugin. Your job is to read all task state files and present a comprehensive, well-formatted dashboard showing the current status of all work.

## Data Collection

### Step 1: Read the global index

Read `.claude/tasks/index.json`. This file follows the schema at `templates/index-schema.json` and contains:

- `epics`: array of epic entries with `specId`, `title`, `status`, `progress`, and `path`
- `standalone`: object with `path`, `total`, and `completed`

If the file does not exist, display:

```
No tasks found. Use /spec to create a specification or /new-task to create a standalone task.
```

And stop.

### Step 2: Read epic state files

For each epic in the `epics` array, read its `state.json` from `.claude/tasks/{path}/state.json`. Parse the tasks array and summary object.

### Step 3: Read standalone state

If `standalone.total > 0`, read `.claude/tasks/{standalone.path}/state.json` to get standalone task details.

## Dashboard Rendering

Present the dashboard in this format:

```
=============================================
        TASK MASTER DASHBOARD
=============================================

EPICS
-----

[1] SPEC-001: User Authentication
    Status: in-progress
    Progress: [####------] 4/10 (40%)
    Phases:  setup(2/2) core(1/4) integration(0/2) testing(1/2)
    Blocked: 2 tasks

[2] SPEC-003: Payment Integration
    Status: pending
    Progress: [----------] 0/8 (0%)
    Phases:  setup(0/1) core(0/4) integration(0/2) testing(0/1)
    Blocked: 0 tasks

STANDALONE TASKS
----------------

    Total: 5 | Completed: 2 | Pending: 2 | In Progress: 1
    Progress: [####------] 2/5 (40%)

BLOCKED TASKS
-------------

    T-005 "Implement OAuth callback" (SPEC-001)
      Blocked by: T-003 "Create auth middleware" (in-progress)

    T-006 "Add session management" (SPEC-001)
      Blocked by: T-003 "Create auth middleware" (in-progress),
                  T-004 "Setup Redis cache" (pending)

NEXT AVAILABLE TASK
-------------------

    Suggested: T-007 "Write login page tests" (SPEC-001)
    Complexity: 3/10 | Phase: testing | Tags: frontend, testing
    Run /next-task to start this task.

STATISTICS
----------

    Total tasks:        23
    Completed:          8 (35%)
    In progress:        3 (13%)
    Pending:            9 (39%)
    Blocked:            3 (13%)
    Cancelled:          0 (0%)

    Avg complexity (remaining): 5.2/10
    Epics:              2 active, 0 completed

=============================================
```

## Dashboard Sections Detail

### EPICS Section

For each epic in the index:

1. Show spec ID and title
2. Show overall status
3. Calculate and show progress bar: `[####------]` using `#` for completed and `-` for remaining, scaled to 10 characters
4. Show per-phase breakdown: count completed vs total for each phase that has tasks
5. Show count of blocked tasks

Sort epics: `in-progress` first, then `pending`, then `completed`.

### STANDALONE TASKS Section

Show summary counts by status. Show a progress bar for completed/total.

Only show this section if standalone tasks exist (total > 0).

### BLOCKED TASKS Section

For each task with status `blocked` or whose `blockedBy` array contains tasks that are not yet `completed`:

1. Show the blocked task ID, title, and which epic it belongs to
2. Show each blocking task with its current status

This helps the user understand what to unblock first.

Only show this section if there are blocked tasks.

### NEXT AVAILABLE TASK Section

Compute the next recommended task:

1. Find all tasks with status `pending`
2. Filter to those whose `blockedBy` array is empty OR all referenced tasks have status `completed`
3. Among those, pick the one with the **lowest complexity** (quick win strategy)
4. If there's a tie, prefer tasks in earlier phases: setup > core > integration > testing > docs > cleanup

Show the task's title, complexity, phase, and tags.

If no tasks are available, show why:
- "All tasks completed!" if everything is done
- "All remaining tasks are blocked" if tasks exist but none are available
- "No tasks found" if there are no tasks at all

### STATISTICS Section

Calculate across ALL tasks (epics + standalone):

- **Total tasks**: sum of all tasks
- **By status**: count and percentage for each status
- **Avg complexity (remaining)**: average complexity of non-completed, non-cancelled tasks
- **Epics**: count active (in-progress + pending) vs completed

## Formatting Rules

- Use fixed-width formatting for alignment
- Progress bars should be exactly 10 characters wide inside brackets
- Percentages should be whole numbers
- Keep the output clean and scannable
- Use separator lines between major sections

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Check existence: `[ -d "$DIR" ] && ls "$DIR" 2>/dev/null || echo "(none)"`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
