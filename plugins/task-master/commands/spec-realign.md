---
name: spec-realign
description: Analyze a spec for drift vs the current codebase and produce a realignment report with direct fixes for unambiguous issues
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
---

# /spec-realign

## Purpose

Detect and fix drift between a written spec and the current codebase. Specs written weeks or months ago may be partially implemented by other teams, made redundant by other specs, or now misaligned with architectural changes. This command produces a structured 4-bucket report and either fixes unambiguous issues directly or asks the user before acting on anything that requires a decision.

## Process

You are the spec realignment analyst for the task-master plugin. Your job is to read a spec exhaustively, read the relevant parts of the codebase exhaustively, and produce a grounded, honest realignment report — no guessing, no paraphrasing from spec text alone.

## Input

The user may provide an optional argument:

- **Spec ID** (e.g., `SPEC-042`): analyze that specific spec
- **No argument**: infer from context

If no argument is provided:

1. Read `.claude/tasks/index.json`
2. Check for any epic with status `"in-progress"` — if exactly one, use it
3. If ambiguous (zero or multiple in-progress), list active epics and ask the user which one to realign

If the index file does not exist:

```
No tasks found. Use /spec to create a specification or /new-task to create a standalone task.
```

And stop.

## Step 1: Load Spec Artifacts

Resolve the spec directory: `.claude/specs/SPEC-NNN-slug/`

Read ALL of the following (handle missing files gracefully):

- `.claude/specs/SPEC-NNN-slug/spec.md` — the full specification
- `.claude/specs/SPEC-NNN-slug/metadata.json` — spec metadata
- `.claude/tasks/SPEC-NNN-slug/state.json` — task execution state
- `.claude/tasks/SPEC-NNN-slug/TODOs.md` — task checklist (if present)
- `.claude/tasks/index.json` — global index for cross-spec context

Present a loading summary:

```
SPEC REALIGN: SPEC-042 "Feature Title"
=======================================

Spec loaded:
  spec.md        found (NNN lines)
  metadata.json  found (status: approved, created: YYYY-MM-DD)
  state.json     found (X/Y tasks, N completed, M pending)
  TODOs.md       found / not found

Starting codebase analysis...
```

## Step 2: Codebase Exploration

**This is the most important step. Do not skip it or rely on memory.**

Identify all code areas the spec touches based on the spec text. Then **read the actual files**. For broad specs (touching 5+ packages or subsystems), delegate exploration to a sub-agent to avoid polluting the main context.

### 2a. Derive search targets from the spec

From the spec text, extract:
- Entity names, service names, model names mentioned
- File paths or packages explicitly referenced
- API endpoint paths mentioned
- Schema names, Zod schemas, DB table names mentioned
- UI component names mentioned
- Enum values, permission names, config keys mentioned

### 2b. Execute codebase reads

For each search target:

```bash
# Find relevant files
grep -rl "<entity_or_service_name>" src/ packages/ apps/ 2>/dev/null | head -20

# Check if specific files exist
[ -f "<path>" ] && echo "EXISTS" || echo "MISSING"
```

Read the actual file content for every hit that is relevant to the spec claims. Do NOT skip this. The report must be grounded in real file state, not inference.

### 2c. Check task completion evidence

For each task in `state.json` with `status: "completed"`, verify the claim:
- Read the files the task was supposed to modify
- Check that the expected code/structure actually exists

For each task with `status: "pending"` or `"blocked"`, check if the code it would create **already exists** from a different source (other spec, manual work, or refactor).

### 2d. Check for structural changes since spec was written

Look for signals that the architectural context has changed:
- Does the file/module the spec targets still exist with the same structure?
- Have the base classes, interfaces, or patterns the spec references been refactored?
- Are there new shared utilities that the spec was going to create from scratch?
- Are there deprecated patterns the spec still uses?

## Step 3: Build Realignment Report

Produce the report in exactly 4 buckets. Every item MUST cite a specific file path, line range, or code evidence. Do not include items without codebase evidence.

```
REALIGNMENT REPORT: SPEC-042 "Feature Title"
=============================================

Analysis based on: <N files read, M search queries>
Report generated: YYYY-MM-DDTHH:MM:SSZ

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BUCKET A — No longer valid (already done or no longer applies)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Items in this spec that are DONE or IRRELEVANT now.

  A-1. [Task T-003 / spec §2.1] "Create XyzService class"
       ALREADY EXISTS: packages/service-core/src/xyz.service.ts (line 1-120)
       Implemented by: SPEC-038 (merged PR #1207 on 2026-04-10)
       Recommendation: Cancel T-003 — no work needed.

  A-2. [spec §3.4] "Add HOSPEDA_XYZ_URL env var to .env.example"
       ALREADY EXISTS: apps/api/.env.example line 42
       Recommendation: Remove this requirement from the spec.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BUCKET B — Half-done (started, needs completion)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Items partially implemented but missing pieces.

  B-1. [Task T-005 / spec §2.3] "Admin route for XYZ list"
       PARTIAL: Route handler exists at apps/api/src/routes/xyz/admin/index.ts
       MISSING: Permission check uses hardcoded role string instead of PermissionEnum.XYZ_VIEW_ALL
       MISSING: Response not wrapped with ResponseFactory (raw c.json used)
       Recommendation: Fix the two gaps. Task T-005 should remain pending.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BUCKET C — Still valid and not started
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Items with no implementation found — spec claims are intact and needed.

  C-1. [Task T-007 / spec §4.1] "Add Zod schema XyzAdminSearchSchema"
       NOT FOUND in packages/schemas/src/entities/xyz/
       Spec requirement is still accurate and not covered elsewhere.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BUCKET D — New additions recommended
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Things found in the codebase that the spec should cover but does not.

  D-1. packages/service-core/src/base.service.ts now exposes runWithLoggingAndValidation()
       The spec's service tasks do not use it. All new services in the codebase use it.
       Recommendation: Add requirement to use runWithLoggingAndValidation() to all service tasks.

  D-2. SPEC-041 added a new PermissionEnum value XYZ_BULK_DELETE.
       The spec's admin route tasks do not mention bulk operations.
       Recommendation: Add a task or note for bulk-delete route (or explicitly out-scope it).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  A (no longer valid):    N items
  B (half-done):          N items
  C (still valid):        N items
  D (new additions):      N items

  Unambiguous fixes (will apply directly): N
  Decisions needed from you:               N
```

## Step 4: Apply Unambiguous Fixes

Apply the following changes **without asking** — they are non-destructive or clearly correct:

- **Cancelling tasks** that are completely done in the codebase (set `status: "cancelled"` in state.json, note the reason)
- **Fixing task descriptions** that reference wrong file paths (the correct path was found in the codebase)
- **Adding a "Revision History" section** to spec.md (if none exists)
- **Updating task status** from `pending` to `blocked` when a dependency is found to exist in an incomplete state

For each unambiguous fix applied, show:

```
APPLIED: [T-003] status → cancelled
  Reason: XyzService already exists at packages/service-core/src/xyz.service.ts (SPEC-038)
```

**Do NOT apply** without asking:
- Removing or rewriting spec sections
- Adding new tasks (Bucket D items)
- Modifying scope or acceptance criteria
- Changing task ordering or dependencies
- Any change that introduces a new architectural decision

## Step 5: Ask Before Acting on Decisions

For every item that needs a user decision, present them one at a time (or grouped if closely related):

```
DECISION NEEDED (1 of N)
========================

Item A-2: spec §3.4 says "Add HOSPEDA_XYZ_URL to .env.example"
The variable already exists at apps/api/.env.example line 42.

Options:
  (a) Remove this requirement from spec.md and cancel the related task
  (b) Keep it in spec — perhaps a different .env.example needs updating
  (c) Skip — leave for manual review

Choose (a/b/c):
```

Wait for user input before each decision. After all decisions are resolved, apply the approved changes.

## Step 6: Write Revision History to spec.md

After all changes are applied, append (or update) a `## Revision History` section at the end of spec.md:

```markdown
## Revision History

| Date | Trigger | Changes | Result |
|------|---------|---------|--------|
| YYYY-MM-DD | spec-realign | A: T-003 cancelled (already in codebase); B: T-005 desc updated (file path corrected); D: runWithLoggingAndValidation requirement added | 2 tasks cancelled, 1 updated, 1 new task added |
```

If the section already exists, append a new row — do NOT remove old rows. The revision history is append-only.

## Step 7: Update Task State

After all approved changes:

### 7a. Recompute summary statistics in state.json

Recalculate the `summary` object:
- `total`: all non-cancelled tasks
- `pending`: tasks with status `"pending"`
- `inProgress`: tasks with status `"in-progress"`
- `completed`: tasks with status `"completed"`
- `blocked`: tasks with status `"blocked"`
- `averageComplexity`: average complexity of non-completed, non-cancelled tasks

### 7b. Update task index

In `.claude/tasks/index.json`, update the epic's `progress` field to reflect the new counts.

### 7c. Regenerate TODOs.md

Regenerate the TODOs.md from the updated state (same format as /replan Step 3c).

## Step 8: Final Report

```
REALIGN COMPLETE: SPEC-042 "Feature Title"
==========================================

Applied automatically:   N changes
Applied after approval:  N changes
Skipped (user choice):   N changes

Updated files:
  .claude/specs/SPEC-042-feature-title/spec.md       (revision history added)
  .claude/tasks/SPEC-042-feature-title/state.json    (N tasks updated)
  .claude/tasks/SPEC-042-feature-title/TODOs.md      (regenerated)
  .claude/tasks/index.json                            (progress updated)

Remaining work: N tasks still pending (Bucket C items)
New tasks added: N (Bucket D items approved)
```

## Notes

- The codebase read in Step 2 is mandatory. Never skip it.
- Every bucket item must cite a real file path or evidence. Vague items ("this might have changed") are not allowed.
- When in doubt about whether something is unambiguous, ask the user — it is always safer to ask.
- The revision history in spec.md is permanent and append-only. Never delete old rows.
- If the spec is very large (many sections, many tasks), delegate the codebase exploration to a sub-agent and pass back a compact findings summary before building the report.

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Check existence: `[ -d "$DIR" ] && ls "$DIR" 2>/dev/null || echo "(none)"`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
