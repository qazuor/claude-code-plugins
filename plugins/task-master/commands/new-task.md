---
name: new-task
description: Create a standalone task directly without requiring a specification
---

# /new-task

## Purpose

Create a standalone task directly in the task group without requiring a full specification. Useful for quick fixes, one-off tasks, or items that don't warrant a full spec.

## Process

You are the standalone task creator for the task-master plugin. Your job is to create a new task directly in the standalone task group, without requiring a full specification.

## Input

The user may provide a title as an argument. Parse the argument as the task title.

If no title is provided, ask:

> What task would you like to create? Please provide a brief title.

## Step 1: Gather Task Details

Ask the user for the following details (or accept them if provided inline):

1. **Title** (required): Brief task title (max 200 characters)
2. **Description** (optional but recommended): Detailed description of what needs to be done. If not provided, prompt for it.
3. **Complexity** (optional): Estimate from 1-10. If not provided, suggest one based on the description:
   - 1-2: Trivial (typo, config change)
   - 3-4: Simple (single file change, straightforward logic)
   - 5-6: Moderate (multiple files, some design decisions)
   - 7-8: Complex (cross-cutting, architectural considerations)
   - 9-10: Very complex (major system changes, high risk)
4. **Tags** (optional): Array of categorization strings. Suggest relevant tags based on the title/description (e.g., `frontend`, `backend`, `database`, `testing`, `docs`, `bugfix`, `security`, `performance`).
5. **Phase** (optional): One of `setup`, `core`, `integration`, `testing`, `docs`, `cleanup`. Default to `core` if not specified.

Present the gathered details for confirmation:

```
New standalone task:

  Title:       Add rate limiting to API
  Description: Implement rate limiting middleware for the public
               API endpoints using a sliding window algorithm.
  Complexity:  5/10
  Tags:        backend, security, performance
  Phase:       core

Create this task? (yes/edit/cancel)
```

## Step 2: Generate Task ID

### 2a. Read existing state

Read `.claude/tasks/standalone/state.json` if it exists.

If the file exists, find the highest task ID number among all existing tasks in the `tasks` array. The new task ID will be `T-NNN` where NNN is the next number, zero-padded to 3 digits.

If the file does not exist, the first task ID will be `T-001`.

### 2b. Also check epic tasks for global uniqueness

Read `.claude/tasks/index.json` if it exists. For each epic, read its `state.json` and find the highest task ID across all epics. The new standalone task ID must be higher than ANY existing task ID across the entire system to ensure global uniqueness.

Example: if SPEC-001 has tasks T-001 through T-010, and standalone has T-011, the next standalone task should be T-012.

## Step 3: Create/Update State File

### 3a. Ensure directory exists

The standalone tasks live in `.claude/tasks/standalone/`. Create this directory if it does not exist.

### 3b. Initialize or update state.json

If `.claude/tasks/standalone/state.json` does not exist, create it:

```json
{
  "version": "1.0",
  "specRef": null,
  "title": "Standalone Tasks",
  "created": "ISO-TIMESTAMP",
  "tasks": [],
  "summary": {
    "total": 0,
    "pending": 0,
    "inProgress": 0,
    "completed": 0,
    "blocked": 0,
    "averageComplexity": 0
  }
}
```

### 3c. Add the new task

Append a new task object to the `tasks` array:

```json
{
  "id": "T-NNN",
  "title": "Task title",
  "description": "Task description",
  "status": "pending",
  "complexity": 5,
  "blockedBy": [],
  "blocks": [],
  "subtasks": [],
  "tags": ["tag1", "tag2"],
  "phase": "core",
  "qualityGate": {
    "lint": null,
    "typecheck": null,
    "tests": null
  },
  "timestamps": {
    "created": "ISO-TIMESTAMP",
    "started": null,
    "completed": null
  }
}
```

All fields must conform to the schema at `templates/state-schema.json`.

### 3d. Update summary

Recalculate the `summary` object:

- `total`: count of all tasks
- `pending`: count of tasks with status `"pending"`
- `inProgress`: count of tasks with status `"in-progress"`
- `completed`: count of tasks with status `"completed"`
- `blocked`: count of tasks with status `"blocked"`
- `averageComplexity`: average of `complexity` across all non-completed, non-cancelled tasks (or 0 if none)

## Step 4: Update Global Index

Read `.claude/tasks/index.json`. If it does not exist, create it:

```json
{
  "version": "1.0",
  "epics": [],
  "standalone": {
    "path": "standalone",
    "total": 0,
    "completed": 0
  }
}
```

Update the `standalone` object:

- `total`: new total count of standalone tasks
- `completed`: count of completed standalone tasks

Write the updated index back to `.claude/tasks/index.json`.

## Step 5: Generate/Update TODOs.md

Create or update `.claude/tasks/standalone/TODOs.md` with all standalone tasks grouped by phase:

```markdown
# Standalone Tasks

Total: N | Completed: M | Progress: M/N

## Setup

- [ ] T-001: Setup CI pipeline (complexity: 3)

## Core

- [ ] T-012: Add rate limiting to API (complexity: 5)
- [x] T-008: Fix database connection pooling (complexity: 4)

## Integration

(none)

## Testing

- [ ] T-010: Add E2E tests for checkout (complexity: 6)

## Docs

(none)

## Cleanup

- [x] T-009: Remove deprecated endpoints (complexity: 2)
```

Rules for TODOs.md:

- Group tasks by `phase` in order: setup, core, integration, testing, docs, cleanup
- Use `- [x]` for completed tasks, `- [ ]` for all others
- Show complexity in parentheses
- Show blocked-by info in brackets if the task has dependencies: `[blocked by T-005]`
- Show `(none)` for phases with no tasks
- Include progress summary at the top

## Step 6: Confirmation

```
Task created successfully!

  ID:          T-012
  Title:       Add rate limiting to API
  Complexity:  5/10
  Phase:       core
  Status:      pending

  Location:    .claude/tasks/standalone/state.json
  TODOs:       .claude/tasks/standalone/TODOs.md

  Run /next-task to start working on it, or /tasks to see the full dashboard.
```

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Create with `mkdir -p` and check with `[ -d "$DIR" ]`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
