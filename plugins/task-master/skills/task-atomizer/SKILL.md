---
name: task-atomizer
description: Breaks a feature or large task into atomic, independently completable sub-tasks organized by implementation phase and layer
---

# Task Atomizer

## Purpose

Break features and large tasks into atomic, independently completable sub-tasks. Organizes by implementation phase (schema, service, API, UI, tests) and layer, with each task sized for 1-3 hours of focused work.

## Patterns

You are a task decomposition engine for the Task Master plugin. Your job is to take a feature description or spec content and break it into atomic, well-ordered sub-tasks that follow a layer-based implementation approach.

## Inputs

You will receive:

1. **Feature description or spec content** - The feature to decompose (raw text, spec.md content, or file path)
2. **Context** (optional) - Codebase structure, tech stack, existing patterns

## Core Principles

1. **Ultra-granular atomic tasks**: Each task must be completable independently with a focused set of files. Prefer many small tasks over few large ones. There is **no maximum number of tasks** — granularity is always preferred over brevity
2. **Layer ordering**: Tasks follow DB -> Service -> API -> Frontend progression
3. **Independent testability**: Each task produces testable output on its own
4. **TDD included**: Unit tests are part of each implementation task, not separate tasks
5. **Clear boundaries**: Each task has a focused set of files to create or modify (ideally 1-5)
6. **Phase organization**: Tasks are grouped by phase (setup → core → integration → testing → docs → cleanup) to create natural pause points for user review between phases

## Maximum Complexity Threshold

**All final tasks MUST have complexity ≤ 4.** Any task scoring above 4 is too complex for atomic execution and must be decomposed further. The decomposition is ONLY complete when every task has complexity ≤ 4.

## Process: Multi-Pass Progressive Decomposition

Instead of producing perfect atomic tasks in one shot, use **multiple passes** of increasing granularity:

```
Pass 1 (Macro):   Feature → Major tasks (high-level breakdown, complexity 5-8 expected)
Pass 2 (Split):   Major tasks → Sub-tasks (split each major task into smaller pieces)
Pass 3+ (Refine): Score all sub-tasks → Re-split any with complexity > 4
Repeat until ALL tasks ≤ 4 complexity (max 5 passes total)
```

### Pass 1: Macro Breakdown

Read the input content and identify:

- **Domain entities** involved (e.g., User, Accommodation, Booking)
- **Layers affected** (database, service, API, frontend, configuration)
- **New vs modified** components
- **External dependencies** needed
- **Cross-cutting concerns** (auth, validation, error handling, logging)

Break the feature into **major functional areas/tasks**. These are high-level — complexity 5-8 is expected at this stage. Do NOT try to make them atomic yet. Each major task represents a logical chunk of the feature (e.g., "Database layer for users", "Authentication middleware", "User profile UI").

### Pass 2: Split Major Tasks

Take each major task from Pass 1 and decompose it into smaller sub-tasks. At this stage:

- Assign phases and dependencies
- Include test requirements in each task
- Target complexity 3-4 per task, but some may still be 5-6

### Pass 3+: Refine (Scoring Loop)

1. Score every task using complexity-scorer criteria
2. Collect all tasks with complexity > 4
3. For each task with complexity > 4, decompose it further:
   - Split by layer (separate DB from service from API)
   - Split by concern (separate validation from core logic)
   - Split by file count (if touching 5+ files, split into per-file tasks)
   - Split by test type (separate unit test setup from integration tests)
4. Re-score the newly created sub-tasks
5. Repeat until ALL tasks have complexity ≤ 4

### Iteration Safety

**Maximum 5 passes total.** If after 5 passes some tasks still exceed complexity 4:

- Flag them with `"splitRequired": true` in the task metadata
- Add a warning note to the task description: `"⚠ COMPLEXITY {score} exceeds maximum 4. Manual review required — use /replan to split before starting."`
- Report the flagged tasks in the output summary

### Completion Validation

The decomposition is **ONLY complete** when:
1. Every task has complexity ≤ 4, OR
2. Maximum iterations (5) reached and remaining high-complexity tasks are flagged for manual review

### Organize Work Units by Phase

Organize tasks into these phases, in order:

#### Phase: `setup`
Configuration, dependencies, environment setup tasks.

Examples:
- Add new npm packages
- Create environment variables
- Set up configuration files
- Create database migration files
- Add new validation schemas

#### Phase: `core`
Database schemas, models, services, and core business logic.

Examples:
- Create ORM schema for new table
- Implement data model
- Create service layer with CRUD operations
- Implement core business logic functions
- Add validation schemas

#### Phase: `integration`
API routes, frontend components, and system connections.

Examples:
- Create API routes using route factories
- Implement frontend pages/components
- Connect frontend to API via data-fetching layer
- Add navigation/routing entries
- Implement form handling and validation

#### Phase: `testing`
Integration tests, E2E tests, and cross-component test suites.

Note: Unit tests are NOT in this phase -- they are included in each task in the `core` and `integration` phases. This phase is for:
- Integration tests that span multiple layers
- E2E tests for user flows
- Performance tests
- Load tests

#### Phase: `docs`
Documentation updates.

Examples:
- Update API documentation
- Update user guides
- Add JSDoc to public APIs
- Create migration guides

#### Phase: `cleanup`
Refactoring, dead code removal, optimization.

Examples:
- Remove deprecated code paths
- Refactor to use new patterns
- Optimize database queries
- Clean up temporary workarounds

### Step 3: Create Task Objects

For each identified work unit, create a task object with these fields:

```json
{
  "id": "T-001",
  "title": "Create product ORM schema",
  "description": "Create the ORM schema definition for the products table. Include all columns from the data model spec: id, name, slug, description, price, status, createdAt, updatedAt. Add appropriate indexes for slug (unique) and status. Write unit tests for schema validation.",
  "status": "pending",
  "complexity": 0,
  "blockedBy": [],
  "blocks": ["T-002", "T-003"],
  "subtasks": [
    { "title": "Define ORM table schema with all columns", "completed": false },
    { "title": "Add database indexes", "completed": false },
    { "title": "Export from barrel file", "completed": false },
    { "title": "Write schema unit tests", "completed": false }
  ],
  "tags": ["database", "schema", "product"],
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
```

### Task Title Guidelines

Titles MUST use imperative verb + noun format:
- "Create product ORM schema"
- "Implement product service CRUD operations"
- "Add price filter API endpoint"
- "Build product list page component"
- "Configure authentication middleware"
- "Write integration tests for booking flow"

Avoid vague titles like:
- "Work on products" (too vague)
- "Product stuff" (not imperative)
- "Fix things" (unclear scope)

### Task Description Guidelines

Each description MUST include:
1. **What to do** — Clear action to take
2. **Where to do it** — Specific files to create or modify (with paths)
3. **How to verify** — How to know the task is complete
4. **Test requirements (MANDATORY)** — Specific tests that MUST be written for this task:
   - **Unit tests:** Which functions to test, which behaviors and edge cases
   - **Integration tests:** Which interactions to test (if task involves multi-component work)
   - **Test files:** Exact test file paths to create or modify
   - **Test patterns:** Fixtures, mocks, or utilities needed

**A task without test requirements is incomplete.** Every task that produces code MUST specify what tests to write. The TDD cycle (Red-Green-Refactor) requires knowing what tests to write BEFORE starting implementation. No tests = not done.

### Step 4: Assign Dependencies

For each task, determine:

- **blockedBy**: Which task IDs must be completed before this task can start
- **blocks**: Which task IDs depend on this task completing

Follow these dependency rules:
1. Schema/migration tasks block model tasks
2. Model tasks block service tasks
3. Service tasks block API route tasks
4. API route tasks block frontend tasks that consume them
5. Setup/config tasks block everything that uses them
6. Testing phase tasks are blocked by the components they test
7. Docs tasks are blocked by the features they document
8. Cleanup tasks are blocked by everything they clean up

### Step 5: Identify Parallel Tracks

Group tasks that have no dependencies between them. These can be worked on simultaneously by different developers or in any order.

Common parallel tracks:
- Independent entity implementations (User model + Product model)
- Frontend and backend for different features
- Documentation for already-completed features
- Test suites for independent components

### Step 6: Validate

Before returning tasks, validate:

1. **No orphan dependencies**: Every ID in `blockedBy`/`blocks` refers to an existing task
2. **No circular dependencies**: A does not (transitively) depend on itself
3. **Complexity ceiling**: Every task MUST have complexity ≤ 4. Any task with complexity > 4 must be decomposed further or flagged for manual review
4. **Phase consistency**: Tasks in earlier phases don't depend on later-phase tasks
5. **Complete coverage**: All aspects of the feature are covered
6. **Granularity check**: Prefer more small tasks over fewer large ones. There is no maximum — 30+ tasks is perfectly acceptable if each is atomic and clear

## Output

Return an array of task objects following the state.json task schema. The tasks should be ordered by:
1. Phase (setup -> core -> integration -> testing -> docs -> cleanup)
2. Dependency level within each phase (no deps first, then level 1, etc.)

Also provide a brief summary:
- Total task count
- Breakdown by phase
- Identified parallel tracks
- Estimated total complexity (sum of individual scores, to be filled by complexity-scorer)
- Suggested starting tasks (those with no dependencies)

## Rules and Constraints

- Tasks MUST follow layer order: DB -> Service -> API -> Frontend
- Each task should modify a focused set of files (ideally 1-5 files)
- Include test writing as part of each implementation task, NOT as separate tasks (unless it's integration/e2e tests spanning multiple components)
- **No maximum number of tasks.** Prefer many granular tasks over few large ones. 30+ tasks is perfectly acceptable if the spec warrants it
- Task IDs are sequential: T-001, T-002, T-003, etc.
- The `complexity` field should be set to 0 initially -- it will be filled by the complexity-scorer skill
- All timestamps use ISO 8601 format
- All `qualityGate` fields start as null
- All tasks start with `status: "pending"`
- **Phase boundaries are pause points.** When all tasks in a phase are complete, the user should be prompted to review before continuing to the next phase
