---
name: spec
description: Generate a specification from requirements - analyzes complexity, checks overlaps, writes spec, and generates tasks
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, mcp__plugin_engram_engram__mem_search, mcp__plugin_engram_engram__mem_save, mcp__plugin_engram_engram__mem_get_observation, mcp__plugin_engram_engram__mem_suggest_topic_key
---

# /spec

## Purpose

Create a structured specification from a user's requirement description. Analyzes complexity, checks for overlaps with existing work, writes a formal spec document, and generates implementable tasks from it.

## Process

You are the specification generator for the task-master plugin. Your job is to take a user's requirement description, analyze it, check for overlaps with existing work, assess complexity, write a structured specification, and generate tasks from it.

## Input

The user may provide a requirement description as an argument. If no argument is provided, ask the user:

> What feature, fix, or improvement would you like to specify? Please describe the requirement in detail.

Store the user's response as `REQUIREMENT`.

## Step 0: Plan Mode — Mandatory Questioning Phase

**CRITICAL — Before anything else, enter Plan Mode and ask the user many questions.**

This step ensures that NOTHING is left to free interpretation during development. The goal is to eliminate ALL ambiguity before writing a single line of spec.

### 0a. Enter Plan Mode

Immediately enter Plan Mode. Do NOT proceed to overlap analysis or spec writing until this phase is complete and the user has approved the plan.

### 0b. Ask Comprehensive Questions

Ask the user questions across ALL of these categories. Do not skip any category. It is better to ask too many questions than too few.

**Functional Requirements:**
- What exactly should happen from the user's perspective?
- What are all the possible user flows (happy path, error path, edge cases)?
- What happens on success? On failure?
- Are there different user roles or permissions involved?
- What data is involved? What are the validation rules?
- What are the acceptance criteria?

**Technical Requirements:**
- Which parts of the codebase are affected?
- Are there architectural decisions to make?
- Are database changes needed? What tables, columns, migrations?
- Are there API changes? New or modified endpoints?
- Are there performance requirements or constraints?
- Are there security considerations?

**Scope Boundaries:**
- What is explicitly IN scope?
- What is explicitly OUT of scope?
- Are there related features that should NOT be touched?
- What is the minimum viable version vs nice-to-have?

**Testing Strategy (CRITICAL — no tests = not done):**
- What unit tests are needed for each new/modified component?
- Which service interactions need integration tests?
- Which API endpoints need integration tests (success, error, auth, validation)?
- Which user flows need E2E tests?
- What specific edge cases MUST have dedicated tests?
- For bug fixes: what regression test reproduces the original bug?
- What existing tests might be affected or need updating?
- What test fixtures, mocks, or test utilities are needed?

**Dependencies and Risks:**
- Are there external dependencies needed?
- Are there internal dependencies or blockers?
- What could go wrong? What are the risks?
- Are there backwards compatibility concerns?

**Alternative Approaches (MANDATORY — evaluate before committing):**
- Is this the simplest possible way to solve the problem? Could a simpler mechanism achieve the same result?
- Are there trade-offs between approaches (complexity vs. flexibility, coupling vs. independence)?
- Does the proposed approach align with existing patterns in the codebase, or would it introduce a new pattern?
- If a new pattern would be introduced, is that justified? What are the long-term maintenance implications?
- Present 2-3 alternative designs to the user and explain the trade-offs for each before finalizing the approach.

**External Services and Libraries (MANDATORY when applicable):**
- Does the feature touch any external API, library, or service (payment processor, authentication provider, cloud storage, etc.)?
- If yes: read the relevant documentation using web search to verify API shapes, authentication flows, error codes, rate limits, and known gotchas. Do NOT rely on training data alone — APIs change.
- List every external integration and the documentation URL you verified against.

**Inconsistency and Conflict Detection:**
- Does this feature overlap in any way with existing functionality already implemented?
- Could this change break or regress any currently working feature?
- Are there naming conflicts, schema conflicts, or permission model conflicts with existing code?
- Does any part of this requirement contradict another part of the same requirement?
- Flag every inconsistency to the user before proceeding.

### 0c. Codebase Exploration (Do Before Finalizing Questions)

Before concluding the questioning phase, explore the actual codebase to inform your questions and identify gaps the user may not have thought about:

1. **Scan affected areas**: Read files in directories related to the feature. Identify existing patterns, naming conventions, and architectural constraints that the spec MUST follow.
2. **Check for existing implementations**: Is there anything already partially implemented or similar to what is being requested? Report findings to the user — they may not know.
3. **Identify implicit constraints**: Does the codebase enforce patterns (e.g., always use a base service class, always validate with Zod, always use a specific response factory)? These must be reflected in the spec.
4. **Flag complexity gaps**: If the user underestimates complexity based on what you see in the code, tell them explicitly.

### 0d. Question Guidelines

- **Do NOT assume.** If something is unclear, ask.
- **Do NOT interpret freely.** If the answer is ambiguous, ask for clarification.
- **Ask follow-up questions.** One answer often reveals the need for more questions.
- **Validate understanding.** Summarize what you understood and ask the user to confirm.
- **10-20 questions is normal** for a medium-to-complex feature. The user prefers thorough questioning over bad assumptions during development.
- **Propose alternatives.** For every significant design decision, present at least 2 options with trade-offs before letting the user decide. Never unilaterally pick an approach without offering alternatives.
- **Comment on quality.** If a proposed approach could be done better, say so directly and explain why. Do not just passively accept the user's first instinct.

### 0e. Overlap Pre-Check (Run During Step 0, Not After)

Do NOT wait for Step 1 to check overlaps. During the questioning phase, scan the resolved specs index (`$SPECS_INDEX`) and tasks index (`$TASKS_INDEX`) for any spec or task that could intersect with the requirement. If overlaps are found, present them to the user as part of the questioning phase so the scope can be adjusted before any spec is written. This prevents writing a spec that duplicates existing work.

### 0f. Get Plan Approval

After all questions are answered, present a summary of the plan:
1. What will be built (functional description)
2. How it will be built (technical approach, with alternatives considered and why this one was chosen)
3. What files will be created/modified
4. What the user flows look like
5. What the edge cases and error handling look like
6. What the testing strategy is
7. What is out of scope (explicitly)
8. What external services/libraries are involved and which docs were verified
9. What inconsistencies or risks were identified

**The user must explicitly approve this plan before proceeding to Step 1.**

## Step 1: Overlap Analysis

Before creating a new spec, check for overlaps with existing specifications and tasks.

### 1a. Read existing indexes

```bash
eval "$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-paths.sh")"
```

Read the following files (they may not exist yet -- handle gracefully):

- `$SPECS_INDEX` -- contains an array of existing spec metadata entries
- `$TASKS_INDEX` -- contains the global task index with epics and standalone tasks

If neither file exists, skip overlap analysis and proceed to Step 2.

### 1b. Scan for overlaps

For each existing spec entry in the resolved specs index:

- Read its `metadata.json` from `$SPECS_DIR/SPEC-NNN-slug/metadata.json`
- Compare the `title`, `tags`, and `type` fields against the new `REQUIREMENT`
- Look for semantic overlap: similar goals, same affected components, overlapping user stories

For each epic in `tasks/index.json`:

- Read its `state.json` from the referenced `path`
- Check if any existing task titles or descriptions overlap with the new requirement

### 1c. Report overlaps

If overlaps are found, present them to the user:

```
Found potential overlaps with existing work:

1. SPEC-002 "User Authentication" (status: in-progress)
   - Overlap: Both involve user login flows
   - Affected tasks: T-005, T-006

2. Standalone task T-012 "Add OAuth provider"
   - Overlap: Related authentication mechanism

Options:
  (a) Continue anyway - create a new independent spec
  (b) Merge - extend the existing spec with new requirements
  (c) Abort - cancel spec creation
```

Wait for the user's choice before proceeding. If the user chooses (b), modify the existing spec instead of creating a new one. If (c), stop entirely.

## Step 2: Assess Complexity

Analyze the `REQUIREMENT` to determine its complexity level:

### Simple (skip spec, create task directly)

- Affects 1-2 files
- Estimated effort: a few hours
- No architectural changes
- No database migrations
- No new dependencies
- Examples: typo fix, config change, small UI tweak

If simple: inform the user that this is simple enough for a standalone task, and suggest using `/new-task` instead. If the user insists on a spec, proceed with spec-lite.

### Medium

- Affects 2-10 files
- Estimated effort: a few days
- Minor architectural considerations
- May involve small DB changes
- May add lightweight dependencies
- Examples: new API endpoint, new UI component, adding validation

If medium: use the **spec-lite** template.

### Complex

- Affects 10+ files
- Estimated effort: multi-day to multi-week
- Significant architectural changes
- Database migrations required
- New external dependencies
- Cross-cutting concerns (auth, performance, security)
- Examples: new entity with full CRUD, authentication system, payment integration

If complex: use the **spec-full** template.

Present the complexity assessment to the user and ask for confirmation:

```
Complexity assessment: MEDIUM
Reasoning: [explanation]

Proceed with spec-lite format? (yes/adjust/override to full)
```

## Step 3: Write Spec from Plan Mode Output

Use the approved plan from Step 0 as the foundation for the specification. The spec must be **super detailed** — it is the contract for development. Everything a developer needs to implement the feature should be in the spec.

**The spec MUST include (where applicable):**
- User stories with detailed acceptance criteria (Given/When/Then) — each criterion becomes a test case
- Technical approach with specific file paths, patterns, and architecture decisions
- Code examples showing expected patterns, API shapes, and data structures
- Data model changes with exact table/column definitions
- API design with request/response examples — each becomes an integration test
- **Testing strategy** — explicit section defining unit, integration, and E2E test requirements
- Error handling for every failure scenario — each becomes an error test
- Edge cases explicitly documented — each becomes an edge case test
- Performance and security considerations

**Every spec MUST include a Testing Strategy section.** The spec defines WHAT to test (SDD), and the development process uses TDD to implement it. No tests = not done.

### 3a. Generate Spec ID

Delegate number allocation to the **spec-allocation skill** (`skills/spec-allocation/`).
It is the single source of the allocation protocol — do NOT reimplement the scan here.

Run the skill's **Allocate** flow. It:

1. Scans `index.json` + `git log --all` via `scripts/scan-spec-numbers.sh` (catches spec
   dirs created on never-merged branches — the strongest collision guard).
2. If engram is available, cross-checks `lastNumber` and reserves the number in the
   `spec-registry/<project>` registry. Engram is best-effort — if it is unavailable the
   skill warns and proceeds on the git+index scan alone. It NEVER blocks spec creation.
3. Returns the zero-padded `SPEC-NNN` number and the directory path
   `<specs-dir>/SPEC-NNN-<slug>/` (resolved via `scripts/resolve-paths.sh`).

Generate the slug from the title (lowercase, hyphens, max 50 chars). ONLY create the
spec directory after the skill returns the number.

> The skill may pause and ask for input if it finds a stale reservation (>14 days old)
> in the registry — resume / abandon / skip. Surface that question to the user.

On the first commit that touches the spec dir, run the skill's **Activate** flow to flip
the reservation from `reserved` to `active`.

### 3b. Enter Plan Mode

Enter Plan Mode to draft the specification. Use the appropriate template:

**For medium complexity (spec-lite):** The template has 5 sections:

1. **Overview** -- Goal, motivation, and success criteria
2. **User Stories & Acceptance Criteria** -- BDD format (Given/When/Then)
3. **Technical Approach** -- High-level approach, key files, dependencies, patterns
4. **Risks** -- Risk table with impact and mitigation
5. **Tasks (Suggested)** -- Preliminary task breakdown

Reference the template at `templates/spec-lite.md` for the full structure.

**For complex (spec-full):** The template has two parts:

Part 1 - Functional Specification:
1. **Overview & Goals** -- Goal, motivation, success metrics, target users
2. **User Stories & Acceptance Criteria** -- BDD format with edge cases
3. **UX Considerations** -- User flows, edge cases, error/loading states, accessibility
4. **Out of Scope** -- Explicitly excluded items

Part 2 - Technical Analysis:
1. **Architecture** -- Pattern, components, integration points, data flow
2. **Data Model Changes** -- Table changes, migrations
3. **API Design** -- Endpoints with auth, request/response shapes, errors
4. **Dependencies** -- External and internal packages
5. **Risks & Mitigations** -- Probability and impact matrix
6. **Performance Considerations** -- Load, bottlenecks, optimization, monitoring

Plus an **Implementation Approach** section with phased task breakdown.

Reference the template at `templates/spec-full.md` for the full structure.

Fill in the template frontmatter:
- `spec-id`: the generated SPEC-NNN
- `type`: one of `feature`, `bugfix`, `refactor`, `improvement`, `infrastructure`, `documentation`
- `complexity`: `medium` or `high`
- `status`: `draft`
- `created`: current ISO 8601 timestamp

### 3c. Internal Review Passes (Before Presenting to User)

Before presenting the spec for user approval, run N internal review passes. Do NOT skip this — it is the last quality gate before the spec becomes a contract for development.

**Pass 1 — Completeness and Junior-Readability Gate:**
Read every section of the spec as if you are a junior developer seeing it for the first time.
- Could a junior developer implement this with zero guessing? If not, add more detail.
- Is every decision explicit? (file paths, function signatures, data shapes, error handling)
- Is anything left to "the developer's judgment"? If yes, either resolve it or flag it as an open question for the user.
- Are all edge cases and error scenarios explicitly documented with expected behavior?

**Pass 2 — Technical Coherence Gate:**
- Is every technical decision coherent with the existing architecture seen in the codebase?
- Does the spec introduce any pattern that conflicts with established conventions?
- Are all the layer interactions correct? (DB → Service → API → Frontend in that order)
- Are dependencies justified and minimal? Does any proposed dependency already exist in the project?

**Pass 3 — External API/Library Accuracy Gate (only if external services are involved):**
- For every external API, library, or service referenced, verify the actual endpoint names, authentication mechanisms, response shapes, and error codes against the real documentation (use web search).
- Replace any guessed or potentially stale information with verified facts.
- Add a note to the spec for each external integration: "Verified against [URL] on [date]."

**Pass 4 — Acceptance Criteria Testability Gate:**
- Can every single acceptance criterion be implemented as an automated test?
- Is each criterion specific enough to have a clear pass/fail condition?
- Are there acceptance criteria that are too vague (e.g., "works correctly", "is fast", "looks good")? Replace with measurable criteria.

**After all passes**, add a `## Internal Review Notes` section at the bottom of the draft listing:
- Any items strengthened during the review
- Any open questions that require user input before implementation
- External docs verified (URLs)

### 3d. Present for approval

After completing all internal review passes, present the spec to the user for review. The user must explicitly approve the spec before it is published.

## Step 4: Publish Specification

After user approval:

### 4a. Create directory structure

```
<specs-dir>/SPEC-NNN-slug/
  spec.md        -- The specification document
  metadata.json  -- Machine-readable metadata
```

### 4b. Write spec.md

Write the approved Plan Mode content as `spec.md`.

### 4c. Write metadata.json

Create `metadata.json` following the schema at `templates/metadata-schema.json`:

```json
{
  "specId": "SPEC-NNN",
  "title": "Spec Title",
  "type": "feature",
  "complexity": "medium",
  "status": "approved",
  "created": "ISO-timestamp",
  "approved": "ISO-timestamp",
  "completed": null,
  "planFileRef": null,
  "tags": ["tag1", "tag2"]
}
```

Tags should be derived from the spec content: affected components, technologies, domains.

### 4d. Update specs index

Create or update `$SPECS_INDEX` to include the new spec entry. If the file does not exist, create it as an array. Add an entry with `specId`, `title`, `type`, `complexity`, `status`, and `path`.

**Always use the `index-sync` skill for this write** so that `tasks/index.json` is updated in the same atomic operation.  NEVER write one index alone.

At this point `tasks/index.json` may not yet have an epic entry for this spec (that is created in Step 5c).  index-sync handles this gracefully — it will create the entry if it does not exist.

## Step 5: Generate Ultra-Granular Atomic Tasks

After spec is published, invoke the **task-from-spec** skill to generate tasks from the approved specification.

**CRITICAL — Task Granularity:** Tasks MUST be extremely granular and atomic. Each task should be independently completable with a focused set of files. There is **no maximum number of tasks** — it is far better to have 30+ small, clear tasks than 8 large, ambiguous ones. Granularity is always preferred over brevity.

**Phase Organization:** Tasks MUST be organized by phases (setup → core → integration → testing → docs → cleanup). Phases serve as natural pause points where the user can review progress and adjust course before continuing.

The skill should:

1. Read the approved `spec.md`
2. Extract the suggested tasks from the spec
3. Expand each into a full task object following the state schema at `templates/state-schema.json`
4. Assign task IDs (T-001, T-002, etc.) within the epic
5. Set appropriate `phase` values: `setup`, `core`, `integration`, `testing`, `docs`, `cleanup`
6. Estimate `complexity` (1-10) for each task
7. Define `blockedBy` and `blocks` dependency relationships
8. Initialize `qualityGate` with null values for lint, typecheck, tests
9. Set `timestamps.created` and leave `started`/`completed` as null
10. Compute `summary` statistics

### 5a. Create task state file

Resolve paths first (each bash block is its own shell, so re-run the resolver here):

```bash
eval "$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-paths.sh")"
```

Write the state to `$TASKS_DIR/SPEC-NNN-slug/state.json` following the state schema.

### 5b. Generate TODOs.md

Generate `$TASKS_DIR/SPEC-NNN-slug/TODOs.md` as a human-readable markdown checklist grouped by phase:

```markdown
# TODOs: [Spec Title]

Spec: SPEC-NNN | Status: in-progress | Progress: 0/N

## Setup
- [ ] T-001: [Task title] (complexity: 3)

## Core
- [ ] T-002: [Task title] (complexity: 5) [blocked by T-001]
- [ ] T-003: [Task title] (complexity: 7) [blocked by T-001]

## Integration
- [ ] T-004: [Task title] (complexity: 4) [blocked by T-002, T-003]

## Testing
- [ ] T-005: [Task title] (complexity: 3) [blocked by T-004]

## Docs
- [ ] T-006: [Task title] (complexity: 2) [blocked by T-005]
```

### 5c. Update task index

Update both `$TASKS_INDEX` **and** `$SPECS_INDEX` using the **index-sync skill**.  NEVER write one index alone.

Use index-sync with:
- `specId`: the newly generated SPEC-NNN
- `newStatus`: `"draft"` (mirrored as `"draft"` in tasks index — the mapping is identity except `approved`→`pending`)
- `newProgress`: `"0/N"` where N is the total number of generated tasks

If the file does not exist, create it following the index schema at `templates/index-schema.json`:

```json
{
  "version": "1.0",
  "epics": [
    {
      "specId": "SPEC-NNN",
      "title": "Spec Title",
      "status": "draft",
      "progress": "0/N",
      "path": "SPEC-NNN-slug"
    }
  ],
  "standalone": {
    "path": "standalone",
    "total": 0,
    "completed": 0
  }
}
```

### 5d. For complex specs: second approval

If the spec was complex, present the full task breakdown to the user for a second round of approval before finalizing. Show:

- All tasks grouped by phase
- Dependency graph (which tasks block which)
- Total estimated complexity
- Critical path (longest dependency chain)

Wait for user approval. Allow the user to modify tasks, reorder, split, or merge before finalizing.

## Step 6: Confirmation

Present a summary to the user:

```
Specification created successfully!

  Spec: SPEC-NNN "[Title]"
  Type: feature | Complexity: medium
  Location: <specs-dir>/SPEC-NNN-slug/

  Tasks generated: N tasks across M phases
  Location: <tasks-dir>/SPEC-NNN-slug/

  Next step: Run /next-task to start working on the first available task.
  Remember: Update task state after completing each task!
  Phases will pause for review between transitions.
```

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Create with `mkdir -p` and check with `[ -d "$DIR" ]`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
- **Index writes**: ALWAYS update both indexes via the `index-sync` skill (Steps 4d and 5c).  NEVER write one index alone.
