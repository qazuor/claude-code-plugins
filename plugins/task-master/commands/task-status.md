---
name: task-status
description: Detailed progress report for a specific spec/epic or all tasks with dependency graph and quality gates
---

# /task-status

## Purpose

Provide an in-depth status report with dependency graphs, critical path analysis, quality gate results, and statistics for a specific spec/epic or the entire project.

## Process

You are the detailed progress reporter for the task-master plugin. Your job is to provide an in-depth status report for either a specific spec/epic or the entire project, including dependency graphs, critical path analysis, quality gate results, and statistics.

## Input

The user may provide an optional argument:

- **Spec ID** (e.g., `SPEC-001`): show detailed report for that specific epic
- **No argument**: show detailed report for ALL epics and standalone tasks

## Step 1: Read Task Data

### For a specific spec

1. Read `.claude/tasks/index.json` to find the epic entry matching the provided spec ID
2. If the spec ID is not found, report: `Spec {ID} not found in task index. Available specs: [list]`
3. Read `.claude/tasks/{path}/state.json` for the matching epic

### For all tasks

1. Read `.claude/tasks/index.json`
2. For each epic, read its `state.json`
3. If standalone tasks exist, read `.claude/tasks/standalone/state.json`

If `.claude/tasks/index.json` does not exist:

```
No tasks found. Use /spec to create a specification or /new-task to create a standalone task.
```

## Step 2: Task-by-Task Status

For each task, display:

```
DETAILED STATUS: SPEC-001 "User Authentication"
================================================

Created: 2025-01-10T09:00:00Z
Overall: [######----] 6/10 (60%)

TASKS
-----

  T-001  Setup auth package structure          setup       COMPLETED
         Complexity: 2 | Completed: 2025-01-11T14:30:00Z
         Quality: lint(pass) typecheck(pass) tests(pass 98%)

  T-002  Define user schema                    setup       COMPLETED
         Complexity: 3 | Completed: 2025-01-12T10:15:00Z
         Quality: lint(pass) typecheck(pass) tests(pass 100%)

  T-003  Create auth middleware                core        IN-PROGRESS
         Complexity: 6 | Started: 2025-01-13T08:00:00Z
         Quality: lint(--) typecheck(--) tests(--)
         Blocks: T-005, T-006, T-008

  T-004  Setup Redis cache                     core        PENDING
         Complexity: 4
         Quality: lint(--) typecheck(--) tests(--)
         Blocks: T-006

  T-005  Implement OAuth callback              core        BLOCKED
         Complexity: 5
         Blocked by: T-003 (in-progress)
         Blocks: T-008

  T-006  Add session management                core        BLOCKED
         Complexity: 7
         Blocked by: T-003 (in-progress), T-004 (pending)
         Blocks: T-008

  T-007  Write login page tests                testing     COMPLETED
         Complexity: 2 | Completed: 2025-01-13T11:00:00Z
         Quality: lint(pass) typecheck(pass) tests(pass 95%)

  ...
```

### Quality gate display rules

- `pass` or `pass NN%`: show green-style indicator with coverage if available
- `fail`: show red-style indicator with details if available
- `--`: not yet evaluated (null)

### Status display

- `COMPLETED`: task is done
- `IN-PROGRESS`: currently being worked on
- `PENDING`: ready to start (no blockers or all blockers resolved)
- `BLOCKED`: waiting on other tasks
- `CANCELLED`: removed from scope

## Step 3: Dependency Graph

Build a text-based dependency graph showing how tasks relate to each other.

### How to build the graph

1. Identify root tasks (tasks with empty `blockedBy`)
2. For each root, traverse `blocks` recursively to build a tree
3. Handle tasks that appear in multiple chains (show them with a reference marker)

### Display format

```
DEPENDENCY GRAPH
----------------

  T-001 (DONE) Setup auth package structure
  +-- T-003 (WIP) Create auth middleware
  |   +-- T-005 (BLOCKED) Implement OAuth callback
  |   |   +-- T-008 (BLOCKED) Integration tests *
  |   +-- T-006 (BLOCKED) Add session management
  |       +-- T-008 (*) [see above]
  +-- T-007 (DONE) Write login page tests

  T-002 (DONE) Define user schema
  +-- T-004 (PENDING) Setup Redis cache
      +-- T-006 (*) [see above]

  T-009 (PENDING) Write API docs        [no dependencies]
  T-010 (PENDING) Update README          [no dependencies]
```

Rules:
- Use `+--` for tree branches and `|` for vertical connectors
- Mark status: `(DONE)`, `(WIP)`, `(BLOCKED)`, `(PENDING)`, `(CANCELLED)`
- When a task appears in multiple branches, mark it with `(*)` and `[see above]` on subsequent appearances
- Independent tasks (no blockedBy, no blocks) appear at the bottom with `[no dependencies]`

## Step 4: Critical Path Analysis

The critical path is the longest chain of dependent tasks from any pending/in-progress task to the final task.

### How to compute critical path

1. Build an adjacency list from `blocks` relationships
2. For each task that has no `blocks` (leaf/terminal tasks), trace back through `blockedBy` to find the longest chain
3. Weight the path by summing `complexity` values
4. The critical path is the chain with the highest total complexity

### Display format

```
CRITICAL PATH
--------------

  Longest dependency chain (by complexity):

  T-003 (6) --> T-005 (5) --> T-008 (8)
  Total complexity: 19 | Tasks remaining: 3

  This path determines the minimum time to completion.
  Focus on T-003 (currently in-progress) to unblock the most work.
```

If there are multiple paths of equal length, show all of them.

If all tasks are completed, show:

```
CRITICAL PATH: All tasks completed! No remaining critical path.
```

## Step 5: Statistics

### Per-epic statistics (when showing a specific spec)

```
STATISTICS
----------

  Total tasks:            10
  Completed:              6 (60%)
  In progress:            1 (10%)
  Pending:                1 (10%)
  Blocked:                2 (20%)
  Cancelled:              0 (0%)

  Total complexity:       45
  Completed complexity:   18 (40%)
  Remaining complexity:   27
  Avg complexity left:    6.8/10

  Time tracking:
    Created:              2025-01-10T09:00:00Z
    First task started:   2025-01-10T09:30:00Z
    Last completion:      2025-01-13T11:00:00Z
    Elapsed:              3 days

  Phase breakdown:
    setup:        2/2 (100%)  [########--]
    core:         1/4 (25%)   [##--------]
    integration:  0/1 (0%)    [----------]
    testing:      1/2 (50%)   [#####-----]
    docs:         0/1 (0%)    [----------]
    cleanup:      0/0 (n/a)
```

### Overall statistics (when showing all)

Show per-epic summaries first, then aggregate statistics:

```
OVERALL STATISTICS
------------------

  Epics:                  3
    SPEC-001:  60% complete (6/10)
    SPEC-003:  0% complete (0/8)
    SPEC-005:  100% complete (5/5)

  Standalone:             5 tasks, 40% complete (2/5)

  Grand total:            28 tasks
  Overall completion:     13/28 (46%)
  Avg complexity left:    5.4/10
```

## Formatting Rules

- Use consistent indentation (2 spaces per level)
- Progress bars: 10 characters wide using `#` and `-` inside brackets
- Percentages: whole numbers
- Timestamps: show full ISO 8601, also show relative time where useful (e.g., "3 days ago")
- Section headers: ALL CAPS with underline separator
- Keep output scannable with clear visual hierarchy
