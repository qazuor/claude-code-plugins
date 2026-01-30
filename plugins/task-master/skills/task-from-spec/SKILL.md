---
name: task-from-spec
description: Parses a spec document and auto-generates a complete task state with scored, dependency-validated, and phase-organized tasks
---

# Task From Spec

## Purpose

Orchestrate end-to-end task generation from approved spec documents. Coordinates the task-atomizer, complexity-scorer, and dependency-grapher skills to produce a complete, scored, dependency-validated, and phase-organized task state.

## Patterns

You are the task generation orchestrator for the Task Master plugin. Your job is to take an approved spec document and produce a complete, ready-to-execute task state file by coordinating the task-atomizer, complexity-scorer, and dependency-grapher skills.

## Inputs

You will receive:

1. **Path to spec.md** - The specification document to generate tasks from
2. **Path to metadata.json** - The spec metadata file in the same directory

## Process

### Step 1: Read Spec and Metadata

Read both files from the provided paths.

From **spec.md**, extract:
- **User stories and acceptance criteria** - Each "US-N" block with its Given/When/Then criteria
- **Technical approach / architecture** - Patterns, components, integration points, data flow
- **Data model changes** - New tables, modified schemas, migrations
- **API design** - New endpoints with auth, request/response shapes
- **Dependencies** - External packages and internal packages affected
- **Implementation approach** - Any pre-defined phase breakdown or task suggestions
- **Risks** - Identified risks and their mitigations
- **Out of scope** - Items explicitly excluded (for spec-full template)
- **UX considerations** - User flows, edge cases, error states (for spec-full template)
- **Performance considerations** - Load expectations, bottlenecks (for spec-full template)

From **metadata.json**, extract:
- `specId` - The spec ID (e.g., "SPEC-003")
- `title` - The spec title
- `complexity` - The overall complexity level
- `type` - The work type (feature, bugfix, etc.)
- `tags` - The categorization tags

### Step 2: Invoke Task Atomizer

Use the task-atomizer skill logic to break down the spec into atomic tasks.

Pass to the atomizer:
- The full spec content as the feature description
- Any available codebase context

The atomizer will return an array of task objects organized by phase (setup -> core -> integration -> testing -> docs -> cleanup).

### Step 3: Invoke Complexity Scorer

Use the complexity-scorer skill logic to score each task from the atomizer.

For each task:
1. Pass the task description and any codebase context
2. Receive back a complexity score (1-10) and justification
3. Update the task's `complexity` field with the score

### Step 4: Invoke Dependency Grapher

Use the dependency-grapher skill logic to validate and optimize the dependency graph.

Pass the full array of tasks with their `blockedBy` and `blocks` fields.

The grapher will:
1. Validate the graph (no cycles, no missing refs)
2. Return topological order, critical path, parallel tracks, and levels
3. If errors are found, fix them before proceeding

If the grapher finds issues:
- **Circular dependencies**: Resolve by removing the suggested edge
- **Missing references**: Add or remove references as suggested
- **Inconsistencies**: Fix bidirectional references

### Step 5: Generate state.json

Create the state file with this structure:

```json
{
  "version": "1.0",
  "specRef": "SPEC-003",
  "title": "The spec title",
  "created": "2025-01-15T10:30:00.000Z",
  "tasks": [
    {
      "id": "T-001",
      "title": "Task title in imperative form",
      "description": "Detailed description with file paths and test expectations",
      "status": "pending",
      "complexity": 5,
      "blockedBy": [],
      "blocks": ["T-002"],
      "subtasks": [
        { "title": "Sub-item 1", "completed": false },
        { "title": "Sub-item 2", "completed": false }
      ],
      "tags": ["database", "schema"],
      "phase": "core",
      "qualityGate": {
        "lint": null,
        "typecheck": null,
        "tests": null
      },
      "timestamps": {
        "created": "2025-01-15T10:30:00.000Z",
        "started": null,
        "completed": null
      }
    }
  ],
  "summary": {
    "total": 8,
    "pending": 8,
    "inProgress": 0,
    "completed": 0,
    "blocked": 0,
    "averageComplexity": 4.5
  }
}
```

**Summary computation:**
- `total`: Number of tasks
- `pending`: Tasks with status "pending"
- `inProgress`: Tasks with status "in-progress"
- `completed`: Tasks with status "completed"
- `blocked`: Tasks with status "blocked"
- `averageComplexity`: Mean of all task complexity scores, rounded to 1 decimal

### Step 6: Create Task Directory

Create the directory: `.claude/tasks/SPEC-NNN-slug/`

Use the same slug from the spec directory name. If the spec directory is `SPEC-003-user-authentication`, the task directory is `.claude/tasks/SPEC-003-user-authentication/`.

Write `state.json` to this directory.

### Step 7: Generate TODOs.md

Create a human-readable task overview in `.claude/tasks/SPEC-NNN-slug/TODOs.md`:

```markdown
# SPEC-NNN: Spec Title

## Progress: 0/N tasks (0%)

**Average Complexity:** X.X/10
**Critical Path:** T-001 -> T-003 -> T-005 -> T-007 (N steps)
**Parallel Tracks:** N tracks identified

---

### Setup Phase

- [ ] **T-001** (complexity: 2) - Task title
  - Description snippet (first 100 chars)
  - Blocked by: none
  - Blocks: T-002, T-003

### Core Phase

- [ ] **T-002** (complexity: 5) - Task title
  - Description snippet
  - Blocked by: T-001
  - Blocks: T-004

- [ ] **T-003** (complexity: 4) - Task title
  - Description snippet
  - Blocked by: T-001
  - Blocks: T-004

### Integration Phase

- [ ] **T-004** (complexity: 6) - Task title
  - Description snippet
  - Blocked by: T-002, T-003
  - Blocks: T-005

### Testing Phase

- [ ] **T-005** (complexity: 5) - Task title
  - Description snippet
  - Blocked by: T-004
  - Blocks: none

### Docs Phase

- [ ] **T-006** (complexity: 2) - Task title
  - Description snippet
  - Blocked by: T-004
  - Blocks: none

---

## Dependency Graph

Level 0: T-001
Level 1: T-002, T-003
Level 2: T-004
Level 3: T-005, T-006

## Suggested Start

Begin with **T-001** (complexity: 2) - it has no dependencies and unblocks 2 other tasks.
```

### Step 8: Update tasks/index.json

Read or create `.claude/tasks/index.json`. This file uses the index schema:

```json
{
  "version": "1.0",
  "epics": [
    {
      "specId": "SPEC-003",
      "title": "Spec Title",
      "status": "pending",
      "progress": "0/8",
      "path": "SPEC-003-user-authentication"
    }
  ],
  "standalone": {
    "path": "standalone",
    "total": 0,
    "completed": 0
  }
}
```

Add the new epic entry or update existing if re-generating.

## Output

After completing all steps, report to the user:

```
Tasks generated successfully from SPEC-003!

  Spec:               SPEC-003 - User Authentication System
  Total tasks:        8
  Average complexity: 4.5/10

  Phase breakdown:
    Setup:        1 task  (avg complexity: 2.0)
    Core:         3 tasks (avg complexity: 5.0)
    Integration:  2 tasks (avg complexity: 5.5)
    Testing:      1 task  (avg complexity: 4.0)
    Docs:         1 task  (avg complexity: 2.0)

  Critical path:     T-001 -> T-003 -> T-005 -> T-007 (4 steps)
  Parallel tracks:   2 identified

  Files created:
    .claude/tasks/SPEC-003-user-authentication/state.json
    .claude/tasks/SPEC-003-user-authentication/TODOs.md
    .claude/tasks/index.json (updated)

  Suggested first task:
    T-001 (complexity: 2) - Create authentication Zod schemas
    No dependencies, unblocks: T-002, T-003

  Ready to start implementing! Use the task runner to begin with T-001.
```

## Error Handling

- **Spec file not found**: Report the error and ask user to provide the correct path
- **Metadata file not found**: Try to infer metadata from spec.md frontmatter, warn the user
- **Empty spec**: Report that the spec has insufficient content and suggest reviewing it
- **Task atomizer produces > 15 tasks**: Warn the user and suggest splitting the spec into phases
- **Circular dependencies detected**: Auto-fix using dependency-grapher suggestions and report what was changed
- **`.claude/tasks/` directory doesn't exist**: Create it
- **Re-generating tasks for existing spec**: Warn user that existing state.json will be overwritten, ask for confirmation
