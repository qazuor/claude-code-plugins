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

### Step 2: Multi-Pass Task Decomposition

Use a **progressive multi-pass approach** to produce ultra-granular atomic tasks that all have complexity ≤ 4. This is more natural and produces better results than trying to atomize everything in one pass.

#### Pass 1: Macro Breakdown

Invoke the task-atomizer skill in **macro mode**:
- Pass the full spec content as the feature description
- Pass any available codebase context
- The atomizer breaks the feature into major functional areas/tasks
- At this stage, complexity 5-8 is expected — do NOT try to make tasks atomic yet

Output: Array of high-level task objects organized by phase.

#### Pass 2: Split Major Tasks

Invoke the task-atomizer skill in **split mode** on each major task from Pass 1:
- Decompose each major task into smaller sub-tasks
- Assign phases, dependencies, and test requirements
- Target complexity 3-4 per task, but some may still be 5-6

Output: Expanded array of smaller task objects.

#### Pass 3: Initial Scoring

Invoke the complexity-scorer on ALL tasks from Pass 2:
- Score each task (1-10) with justification
- Mark tasks with `splitRequired: true` when complexity > 4
- Update each task's `complexity` field

#### Pass 4+: Refinement Loop

**While any task has complexity > 4:**

1. Collect all tasks with complexity > 4
2. Invoke the task-atomizer on ONLY those tasks (further decomposition)
3. Re-score the newly created sub-tasks using the complexity-scorer
4. Replace the original high-complexity tasks with the new sub-tasks
5. Re-assign task IDs sequentially (T-001, T-002, ...) and fix all dependency references
6. Increment the iteration counter

**Iteration safety:** Maximum 5 total passes (Pass 1 + Pass 2 + up to 3 refinement loops). If tasks still exceed complexity 4 after 5 passes:
- Flag remaining high-complexity tasks with a warning in their description: `"⚠ COMPLEXITY {score} exceeds maximum 4. Manual review required — use /replan to split before starting."`
- Report them prominently in the output summary
- These tasks will be blocked from execution by the quality-gate and next-task command

#### Completion Criteria

The decomposition loop is **ONLY complete** when:
- Every task has complexity ≤ 4, OR
- Maximum iterations (5) reached and remaining tasks are flagged for manual review

### Step 3: Invoke Dependency Grapher

After all tasks are at complexity ≤ 4 (or flagged), invoke the dependency-grapher skill to validate and optimize the final dependency graph.

Pass the full array of tasks with their `blockedBy` and `blocks` fields.

The grapher will:
1. Validate the graph (no cycles, no missing refs)
2. Return topological order, critical path, parallel tracks, and levels
3. If errors are found, fix them before proceeding

If the grapher finds issues:
- **Circular dependencies**: Resolve by removing the suggested edge
- **Missing references**: Add or remove references as suggested
- **Inconsistencies**: Fix bidirectional references

### Step 4: Generate state.json

Create the state file. **All tasks in the state file MUST have complexity ≤ 4** (enforced by the multi-pass decomposition in Step 2). The state-schema.json validates this constraint.

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
      "complexity": 3,
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

### Step 5: Create Task Directory

Create the directory: `.claude/tasks/SPEC-NNN-slug/`

Use the same slug from the spec directory name. If the spec directory is `SPEC-003-user-authentication`, the task directory is `.claude/tasks/SPEC-003-user-authentication/`.

Write `state.json` to this directory.

### Step 6: Generate TODOs.md

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

### Step 7: Update tasks/index.json

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
  Total tasks:        14
  Average complexity: 2.8/4 (max)
  Decomposition:     3 passes (all tasks ≤ 4 complexity)

  Phase breakdown:
    Setup:        2 tasks (avg complexity: 1.5)
    Core:         5 tasks (avg complexity: 3.2)
    Integration:  4 tasks (avg complexity: 3.0)
    Testing:      2 tasks (avg complexity: 2.5)
    Docs:         1 task  (avg complexity: 1.0)

  Critical path:     T-001 -> T-004 -> T-008 -> T-012 (4 steps)
  Parallel tracks:   3 identified

  Complexity guarantee:
    All 14 tasks have complexity ≤ 4  ✓
    No tasks require further splitting  ✓

  Files created:
    .claude/tasks/SPEC-003-user-authentication/state.json
    .claude/tasks/SPEC-003-user-authentication/TODOs.md
    .claude/tasks/index.json (updated)

  Suggested first task:
    T-001 (complexity: 1) - Create authentication Zod schemas
    No dependencies, unblocks: T-002, T-003

  Ready to start implementing! Use the task runner to begin with T-001.
```

If any tasks still exceed complexity 4 after maximum iterations (5 passes):

```
  ⚠ Complexity warnings:
    T-009 (complexity: 5) - FLAGGED for manual review. Use /replan to split.
    T-012 (complexity: 6) - FLAGGED for manual review. Use /replan to split.

  These tasks will be blocked from execution until split to complexity ≤ 4.
```

## Task Granularity

Tasks generated from the spec MUST be **ultra-granular and atomic**. There is **no maximum number of tasks** — it is far better to have 30+ small, clear tasks than 8 large, ambiguous ones. Each task should:

- Be completable independently
- Touch a focused set of files (ideally 1-5)
- Have clear start and end conditions
- **Include specific test requirements** (what unit tests, integration tests, and E2E tests to write)
- Be verifiable through quality gates

Tasks MUST be organized by phases (setup → core → integration → testing → docs → cleanup). Phase boundaries serve as **natural pause points** where the user can review progress and adjust course before continuing to the next phase.

## TDD and Testing Requirements

Every task that produces code MUST include test requirements in its description. **No tests = not done.**

### Test Requirements Per Task

Each task description MUST specify:

1. **Unit tests** — Functions to test, behaviors to verify, edge cases to cover
2. **Integration tests** (if applicable) — Interactions to test, endpoints to verify
3. **Test files** — Exact file paths for test files to create or modify
4. **Test expectations** — What assertions to make, what outcomes to verify

### How SDD+TDD Applies to Task Generation

The spec provides the acceptance criteria (SDD). Each acceptance criterion translates to one or more test cases. When generating tasks:

- Extract test cases from the spec's user story acceptance criteria
- Extract test cases from the spec's edge cases section
- Extract test cases from the spec's error handling section
- Distribute test cases across tasks: each task gets the tests relevant to its scope
- Core phase tasks include unit tests (TDD: write test first, then implement)
- Integration phase tasks include integration tests (TDD: write test first, then implement)
- Testing phase tasks include cross-cutting E2E tests

## Error Handling

- **Spec file not found**: Report the error and ask user to provide the correct path
- **Metadata file not found**: Try to infer metadata from spec.md frontmatter, warn the user
- **Empty spec**: Report that the spec has insufficient content and suggest reviewing it
- **Circular dependencies detected**: Auto-fix using dependency-grapher suggestions and report what was changed
- **`.claude/tasks/` directory doesn't exist**: Create it
- **Re-generating tasks for existing spec**: Warn user that existing state.json will be overwritten, ask for confirmation
