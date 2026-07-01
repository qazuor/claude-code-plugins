---
name: spec-review
description: Deep-review an existing spec for completeness, correctness, and junior-implementability — runs N improvement passes, edits trivial fixes directly, asks before decision-requiring changes, and documents each pass in a Revision History section
---

# /spec-review

## Purpose

Exhaustively analyze and strengthen an existing specification. Runs multiple improvement passes combining spec analysis, codebase exploration, and external library verification. Trivial or unambiguous improvements are applied directly; changes that require a decision are presented to the user before editing. Every pass is documented in a `## Revision History` section appended to the spec file.

## Input

The user provides a spec ID as an argument (e.g., `/spec-review SPEC-042`).

If no argument is provided, ask:

> Which spec would you like to deep-review? Provide the spec ID (e.g., SPEC-042).

Store the spec ID as `SPEC_ID`.

## Step 0: Locate and Load the Spec

Before accessing any files, resolve paths:

```bash
eval "$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-paths.sh")"
```

1. **If `$TM_BACKEND=linear`**: `mcp__linear__get_issue({ id: SPEC_ID })` to confirm the identifier exists (`SPEC_ID` is a Linear ID like `HOS-12` in this mode). **If `$TM_BACKEND=local`** (default): read the specs index (`$SPECS_INDEX`) to find the entry for `SPEC_ID`.
2. Derive the spec directory: `$SPECS_DIR/<SPEC_ID>-<slug>/`
3. Read `spec.md` from that directory. If the file does not exist:
   ```
   ERROR: No spec.md found for SPEC_ID at expected path.
   Check the resolved specs index (local) or Linear (linear) for the correct path.
   ```
4. **Local backend only**: read `metadata.json` from the same directory (handle gracefully if missing). On Linear, the same fields live in spec.md's own frontmatter — no separate file to read.
5. Store the original spec content. All subsequent passes mutate a working copy; the original is preserved for diff generation.

## Step 1: Initial Assessment

Before running improvement passes, produce a quick initial assessment that informs how deep the review needs to go:

```
SPEC-REVIEW: SPEC_ID "[Title]"
===============================

Initial assessment:
  Sections present:    [list detected sections]
  Sections missing:    [required sections not found]
  User stories:        N stories found
  Acceptance criteria: N criteria found (N testable / N vague)
  External services:   [list any external APIs/libs mentioned]
  Revision history:    [existing pass count, or "none"]

Complexity estimate:   [low / medium / high]
Estimated passes:      N (will adjust as issues are found)
```

Present this to the user before starting passes. Proceed automatically (do not wait for approval) unless the user says to stop.

## Step 2: Improvement Passes

Run improvement passes sequentially. Each pass focuses on a specific quality dimension. The number of passes scales with the spec's complexity and the issues found — a simple spec may need 2-3 passes; a complex one may need 5+. Always run at minimum the 4 mandatory passes defined below.

After every pass, update the spec's working copy immediately. Do NOT batch all edits to the end.

---

### Pass 1 — Completeness Audit (MANDATORY)

Check every required section against the appropriate template (spec-lite or spec-full based on complexity):

- **Missing sections**: Add skeleton content and flag as `[NEEDS USER INPUT]` if the content cannot be inferred from context.
- **Thin sections**: Sections present but with only 1-2 sentences where 10+ are appropriate — expand with inferred content and note the expansion in the pass log.
- **Testing Strategy**: If absent or skeletal, add an explicit testing strategy section defining unit tests (which functions/modules), integration tests (which service interactions), API tests (which endpoints with which scenarios), and E2E tests (which user flows). Name the test files.
- **Error handling**: Every flow that can fail must document the failure outcome. Add missing error scenarios.
- **Edge cases**: Identify edge cases not mentioned and add them with explicit expected behavior.

**Edit policy for Pass 1**: All additions and expansions are applied directly without asking — these are additions, not removals or changes to existing decisions.

---

### Pass 2 — No-Ambiguity / Junior-Implementability Gate (MANDATORY)

Read the spec as a junior developer with no prior context about the project:

- **Ambiguous terms**: Replace vague language ("handle appropriately", "validate as needed", "similar to the existing pattern") with concrete descriptions.
- **Implicit file paths**: If the spec says "add a new service" without saying where, add the exact expected file path following the project's naming conventions (infer from codebase if needed).
- **Implicit data shapes**: If an API endpoint or function is described without its full request/response shape, add the complete type definition.
- **Decision points without resolution**: If the spec says "either approach A or B could work" without committing, flag it as a decision question for the user (do not decide unilaterally).
- **Vague acceptance criteria**: Any criterion using language like "works correctly", "is responsive", "looks good", "is fast" — rewrite with a measurable outcome or flag for the user.

**Edit policy for Pass 2**:
- Clarifications and concrete replacements: apply directly.
- Unresolved decision points: collect and ask the user (see Step 3).

---

### Pass 3 — Codebase Alignment Audit (MANDATORY)

Read the actual files in the codebase that the spec references or implies:

1. For every file path, module, function, class, table, or column mentioned in the spec: verify it exists and matches the described behavior.
2. For every architectural pattern the spec prescribes (e.g., "extend BaseCrudService", "use ResponseFactory", "validate with Zod via @repo/schemas"): verify the pattern exists in the codebase and the spec's description is accurate.
3. For every database table change described: verify current schema matches the "before" state assumed by the spec.
4. Produce a **Divergence Report** section listing every discrepancy found:
   ```
   ## Divergence Report (Pass 3)
   - spec claims X → actual code has Y (file: path/to/file.ts:line)
   - spec references function foo() → function does not exist; closest match is bar() in path/to/file.ts
   ```
5. Fix divergences where the fix is unambiguous (wrong file path, outdated function name, renamed column). Flag divergences where a real decision is needed.

**Edit policy for Pass 3**:
- Factual corrections (wrong names, wrong paths, outdated shapes): apply directly.
- Structural discrepancies that require re-architecting: collect and ask the user.

---

### Pass 4 — External Services / Libraries Verification (MANDATORY when applicable; SKIP if none)

If the spec mentions any external API, third-party library, cloud service, payment processor, authentication provider, or any integration not entirely controlled by this codebase:

1. Use web search to fetch the current official documentation for each external service mentioned.
2. Verify every claim in the spec:
   - Endpoint paths and HTTP methods
   - Authentication mechanism (API key, OAuth, JWT, webhook signature)
   - Request body structure and required fields
   - Response shape (success and error)
   - Error codes and their meanings
   - Rate limits and quotas
   - Webhooks (payload shape, signature verification method, retry behavior)
3. Correct any inaccurate or stale information found.
4. Add a `## External References Verified` subsection listing:
   ```
   - [Service name]: [URL verified against] — verified [date]
   ```
5. If a claim cannot be verified (docs not found, ambiguous docs), mark it as `[UNVERIFIED — must confirm before implementation]` rather than leaving it as-is.

**Edit policy for Pass 4**: All corrections from verified docs are applied directly. Unverifiable claims are marked but not removed.

---

### Pass 5+ — Architecture and Risk Deep-Dive (run for medium/high complexity specs)

Additional passes for more complex specs:

**Pass 5 — Architecture Consistency:**
- Does the proposed architecture introduce a new pattern not present elsewhere in the codebase? If yes, flag it as a risk and propose an alternative using existing patterns.
- Are there N+1 query risks, missing indexes, or unbounded list queries in the data access design?
- Is there a caching strategy where one is needed?
- Are there security implications (auth gaps, missing validation, exposed sensitive data) not addressed?

**Pass 6 — Task Breakdown Quality (if tasks exist):**
- Read the associated `state.json` from `$TASKS_DIR/<SPEC_ID>-<slug>/state.json` if it exists.
- Are all tasks atomic? (complexity ≤ 3, single clear deliverable)
- Does every task have an explicit test requirement?
- Are dependencies correctly modeled?
- Are there tasks in the spec's implementation approach that are missing from the task list?
- Propose additions or splits to the user — do NOT edit `state.json` directly (task changes go through `/replan`).

---

## Step 3: User Decision Questions

After completing all passes, collect all flagged decision points (items from any pass that required a user decision before editing). Present them in a numbered list:

```
DECISIONS NEEDED BEFORE APPLYING:
===================================

The following items were found during the review but require your input before I can edit the spec:

1. [Pass 2] Acceptance criterion "the UI should respond quickly" — what is the measurable threshold?
   Options: (a) < 200ms for API response, (b) < 1s for full page render, (c) specify your own

2. [Pass 3] The spec references table `billing_subscriptions.plan_type` but the actual column is `plan_id`.
   The spec seems to intend the plan's type string. Should I:
   (a) Change the spec to use `plan_id` and add a join to fetch type, or
   (b) Propose adding a `plan_type` denormalized column (new design decision)?

3. [Pass 5] The architecture proposes a new "EventBus" pattern not found elsewhere in the codebase.
   Options: (a) Keep EventBus — accept introducing this pattern, (b) Rewrite using existing service-call pattern

Answer each item with the option letter or your own answer.
```

Wait for the user's answers. Apply each decision to the spec before finalizing.

## Step 4: Finalize and Document

After all passes are complete and all user decisions are applied:

### 4a. Append Revision History

Append or update a `## Revision History` section at the end of `spec.md`. Each entry records one complete `/spec-review` run:

```markdown
## Revision History

### Review Pass N — [date]
**Passes run:** [list of pass names]
**Summary of changes:**
- Added: [N items added — brief description]
- Modified: [N items changed — brief description]
- Flagged: [N items flagged as open questions resolved by user]
- Divergences found: [N — brief list]
- External refs verified: [list or "none"]
**Open questions remaining:** [list any NOT yet resolved, or "none"]
```

### 4b. Write updated spec.md

Write the finalized working copy back to `$SPECS_DIR/<SPEC_ID>-<slug>/spec.md`.

### 4c. Update metadata.json (LOCAL BACKEND ONLY)

Update the `updated` timestamp in `metadata.json`:

```json
{
  "updated": "ISO-timestamp",
  "reviewPasses": N
}
```

If `reviewPasses` does not exist in the schema yet, add it.

On the Linear backend, skip this — there is no metadata.json; the review's
outcome is already captured in the spec.md Revision History (Step 4a/4b) and,
if it changed scope meaningfully, worth a short comment on the Linear issue.

## Step 5: Report

Present a final report to the user:

```
SPEC-REVIEW COMPLETE: SPEC_ID "[Title]"
========================================

Passes completed:  N
Changes applied:   N direct edits
Decisions resolved: N (from user input)
Open questions:    N remaining (listed in spec under ## Revision History)

What was added:
  + [list key additions]

What was modified:
  ~ [list key modifications]

What was NOT changed (needs follow-up):
  ? [list open questions with their spec section]

Divergences fixed:  N
External refs verified: [list or "none"]

Running review count: N total passes on this spec (across all /spec-review runs)

Recommended next step:
  - If open questions > 0: resolve them, then run /spec-review SPEC_ID again
  - If open questions = 0 and tasks exist: run /replan SPEC_ID to align tasks with the updated spec
  - If open questions = 0 and no tasks yet: run /task-master:task-from-spec to generate tasks
```

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Create with `mkdir -p` and check with `[ -d "$DIR" ]`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
- **Never lose content**: The original spec content must be preserved as the base. Passes ADD and IMPROVE — they do not delete existing correct content.
- **Always document**: Every pass must produce an entry in `## Revision History`. A spec-review run with no history entry is incomplete.
