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

First resolve the backend: `eval "$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-paths.sh")"`.

**If `$TM_BACKEND=linear`, skip Steps 0-1 below entirely** (they only make sense
when there are two local indexes to compare/read) and instead:

1. `ToolSearch` for `select:mcp__linear__list_issues` if not already loaded.
2. `mcp__linear__list_issues({ team: "$TM_LINEAR_TEAM", labels: ["kind-spec"] })` —
   this list IS the epics. There is no drift check to run: Linear is the single
   registry, so there's nothing for it to disagree with. (A different kind of
   consistency issue CAN still happen — a Linear issue whose `.specs/<id>-slug/`
   folder was deleted or never created — but that's a filesystem/Linear mismatch,
   not an index-vs-index drift; flag it inline per-epic in Step 2 below instead of
   a separate pre-pass.)
3. Then continue at **Step 2 (Linear variant)** below to read each epic's task
   state, and **Step 3** for standalone tasks (unchanged, resolved via `$STANDALONE_DIR`).

**If `$TM_BACKEND=local`** (default), continue with Steps 0-3 below, unchanged.

### Step 0: Drift Cross-Check (Run Before Any Rendering, LOCAL BACKEND ONLY)

Before reading epic state files, verify that the two indexes agree on every spec's status.  This catches drift that accumulated from previous sessions where one index was written without the other.

```bash
# Only run the check when both files exist
if [ -f "$SPECS_INDEX" ] && [ -f "$TASKS_INDEX" ]; then
  # For each specId present in tasks/index.json, compare its status against specs/index.json
  # Status mapping is IDENTITY (tasks mirrors spec status exactly), with a single
  # exception: specs "approved" => tasks "pending".  This MUST stay in sync with the
  # mapping table in skills/index-sync/SKILL.md Step 2.
  jq -r --slurpfile specs "$SPECS_INDEX" '
    .epics[] |
    .specId as $id |
    .status as $task_status |
    ($specs[0].specs // [] | map(select(.specId == $id)) | first) as $spec_entry |
    if $spec_entry == null then empty  # spec not in specs index yet — skip
    else
      ($spec_entry.status) as $spec_status |
      # Compute expected tasks status from spec status (identity except approved→pending)
      (if $spec_status == "approved" then "pending" else $spec_status end) as $expected_task_status |
      if $task_status != $expected_task_status
      then "DRIFT|\($id)|\($spec_status)|\($task_status)"
      else empty
      end
    end
  ' "$TASKS_INDEX" 2>/dev/null
fi
```

If any `DRIFT|...` lines are produced, display a warning banner **before** the main dashboard:

```
⚠ INDEX DRIFT DETECTED
=======================
The following specs have inconsistent status between the two indexes.
specs/index.json is authoritative.  Run /spec-realign or re-run any
task-master command that writes to the index to reconcile.

  SPEC-NNN  specs: "completed"  tasks: "in-progress"   ← needs reconciliation
  SPEC-MMM  specs: "cancelled"  tasks: "pending"        ← needs reconciliation

Use the index-sync skill to repair.
=======================
```

This is a read-only warning — the dashboard does NOT auto-repair drift.  It only surfaces it so the user can act.

### Step 1: Read the global index (LOCAL BACKEND ONLY)

Read the tasks index (resolved via `scripts/resolve-paths.sh` as `$TASKS_INDEX`). This file follows the schema at `templates/index-schema.json` and contains:

- `epics`: array of epic entries with `specId`, `title`, `status`, `progress`, and `path`
- `standalone`: object with `path`, `total`, and `completed`

If the file does not exist, display:

```
No tasks found. Use /spec to create a specification or /new-task to create a standalone task.
```

And stop.

On the Linear backend, "no tasks found" instead means the Step 0 (Linear variant)
`list_issues` call returned zero epics AND `$STANDALONE_DIR` has no `state.json` —
show the same message in that case.

### Step 2: Read epic state files

**Local backend**: for each epic in the `epics` array, read its `state.json` from `$TASKS_DIR/{path}/state.json`. Parse the tasks array and summary object.

**Linear backend**: for each issue from Step 0, read `$SPECS_DIR/<id>-<slug>/tasks/state.json`
(nested inside that spec's own folder — there is no parallel tasks tree in this
mode). If the folder or `state.json` doesn't exist yet (issue created but spec.md
work — or task atomization — hasn't happened), show it in the dashboard with
`Progress: not atomized yet` instead of a progress bar, rather than erroring.

### Step 3: Read standalone state

Read `$STANDALONE_DIR/state.json` (resolved via `scripts/resolve-paths.sh` — this
path is the same shape in both backends) to get standalone task details, if it
exists.

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

Sort epics by status in this order: `in-progress`, `pending`, `draft`, `reserved`, `completed`, `merged`, `obsolete`, `cancelled`.  (Active work first; terminal/archived states last.)

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
- **Avg complexity (remaining)**: average complexity of tasks not in a terminal state (`completed`, `cancelled`, `merged`, `obsolete`)
- **Epics**: count active (`in-progress` + `pending` + `draft`) vs terminal (`completed` + `merged` + `obsolete` + `cancelled`)

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
- **Index writes**: This command is read-only — it NEVER writes to either index.  All status/progress writes happen via the `index-sync` skill in the commands/skills that mutate state.
