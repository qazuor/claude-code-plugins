---
name: quality-gate
description: Runs lint, typecheck, and test quality checks before marking a task as completed, updating state and regenerating progress reports
---

# Quality Gate

## Purpose

Enforce quality standards before task completion by running lint, typecheck, and test checks. Records results, blocks completion on failures, and regenerates progress reports after updates.

## Patterns

You are the quality gate enforcement engine for the Task Master plugin. Your job is to run quality checks on completed work, record the results, and only mark tasks as completed when all required checks pass.

## Inputs

You will receive:

1. **Task ID** - The task to run quality checks on (e.g., "T-003")
2. **State file path** - Path to the state.json file containing the task

## Process

### Step 1: Read Task State

Read the `state.json` file at the provided path. Find the task matching the given Task ID.

Validate:
- The task exists in the state file
- The task status is `in-progress` or `pending` (not already `completed` or `cancelled`)
- If the task is `blocked`, report which tasks must complete first and exit

### Step 2: Determine Checks to Run

Look for configuration in this order:

#### Priority 1: Project Config File

Check for `.claude/task-master.config.json` in the project root:

```json
{
  "qualityGate": {
    "lint": { "command": "pnpm lint", "required": true },
    "typecheck": { "command": "pnpm typecheck", "required": true },
    "tests": { "command": "pnpm test", "required": true },
    "coverage": { "threshold": 90, "required": false }
  }
}
```

If this file exists, use its configuration.

#### Priority 2: Auto-Detection

If no config file exists, auto-detect the project's tooling:

1. **Package manager detection:**
   - If `pnpm-lock.yaml` exists -> use `pnpm`
   - If `yarn.lock` exists -> use `yarn`
   - If `package-lock.json` exists -> use `npm`
   - Default: `npm`

2. **Script detection** (read `package.json`):
   - If `scripts.lint` exists -> lint command = `{pm} run lint`
   - If `scripts.typecheck` exists -> typecheck command = `{pm} run typecheck`
   - If `scripts.test` exists -> test command = `{pm} run test`
   - If `scripts.test:coverage` exists -> coverage command = `{pm} run test:coverage`

3. **Tool detection** (if scripts don't exist):
   - Check for `eslint.config.*` or `.eslintrc.*` -> `npx eslint .`
   - Check for `tsconfig.json` -> `npx tsc --noEmit`
   - Check for `vitest.config.*` -> `npx vitest run`
   - Check for `jest.config.*` -> `npx jest`

4. **Monorepo detection (MANDATORY scoping rules):**

   Running the full test suite in a large monorepo spawns unlimited parallel workers across every package simultaneously. On a developer machine this exhausts memory and CPU, causing hangs or crashes. Scoped execution is NOT optional — it is the default.

   **Rule A — scoped run (preferred):**
   - If `turbo.json` exists AND the task's changed files can be localized to a single package, you MUST scope the test run to that package. NEVER run the full suite when a scoped command is available.
   - Determine the package by inspecting the task's file paths: if every changed file lives under `packages/<pkg>/` or `apps/<pkg>/`, that is the target package.
   - Run: `turbo run test --filter=<package>` (Turborepo) or `cd packages/<pkg> && pnpm run test` (direct).
   - Example: task files all in `packages/db/` → `turbo run test --filter=@repo/db` or `cd packages/db && pnpm test`

   **Rule B — concurrency-capped full run (fallback when scope cannot be determined):**
   - Use this ONLY when changed files span multiple packages or the package boundary cannot be determined.
   - Apply a hard concurrency cap to prevent spawning unlimited workers:
     - **vitest**: append `--pool=forks --poolOptions.forks.maxForks=2 --reporter=dot`
     - **jest**: append `--maxWorkers=2`
   - The cap defaults to 2 workers and is configurable via `qualityGate.tests.maxConcurrency` in `.claude/task-master.config.json`.
   - Example capped commands: `pnpm test -- --pool=forks --poolOptions.forks.maxForks=2 --reporter=dot` (vitest) or `pnpm test -- --maxWorkers=2` (jest)

   Choosing between the rules: check `git diff --name-only HEAD` (or the task's file list) against the package directories. If all paths share a common `packages/<pkg>` or `apps/<pkg>` prefix → Rule A. Otherwise → Rule B.

### Step 3: Run Quality Checks

Execute each check sequentially. For each check:

1. **Announce** what is being run: "Running lint check..."
2. **Execute** the command
3. **Capture** the exit code and output
4. **Record** the result:
   - `status`: "pass" (exit code 0) or "fail" (non-zero exit code)
   - `timestamp`: Current ISO 8601 timestamp
   - `details`: First 500 characters of output if failed, empty if passed
   - `coverage`: (only for test check) Extract coverage percentage if available

Run checks in this order:
1. **complexity-check** - Verify task complexity ≤ 3 (pre-flight check)
2. **lint** - Code style and quality
3. **typecheck** - Type safety
4. **tests** - Test suite execution
5. **test-existence** - Verify new tests were written for this task

If a required check fails, continue running remaining checks (to give a complete picture) but the overall gate will fail.

### Complexity Check (Pre-flight)

**CRITICAL: This is the first check and acts as a safety net.** Before running any other quality checks, verify that the task's complexity score is ≤ 3.

- Read the task's `complexity` field from state.json
- If complexity > 3: gate FAILS immediately with message:
  ```
  FAIL: Task complexity {score} exceeds maximum 3.
  This task is too complex for atomic execution and must be decomposed first.
  Use /replan to split this task into smaller tasks with complexity ≤ 3.
  ```
- If complexity ≤ 3: check PASSES, continue to lint check

This prevents any task that slipped through the multi-pass decomposition from being completed without proper splitting.

### Test Existence Check

**CRITICAL: No tests = not done.** After running the test suite, verify that the task actually includes new or modified test files. A task that produces code but adds zero tests MUST NOT be marked as completed.

To verify test existence:
1. Check the task's staged or modified files for test files (files matching `*.test.ts`, `*.spec.ts`, `*.test.tsx`, `*.spec.tsx`, or within a `__tests__/` directory)
2. If the task is in the `core`, `integration`, or `setup` phase and has NO test files, the quality gate FAILS
3. The `docs` and `cleanup` phases are exempt from this check (docs do not require tests; cleanup tasks that only remove code may not need new tests)

Report test existence as part of the quality gate output:
- `tests-added: YES (3 new test files)` — gate passes
- `tests-added: NO` — gate fails with message: "No new tests found. Every code change must include tests. No tests = not done."

### Step 3.5: Pre-Write Validation

Before writing ANY result back to `state.json`, run invariant checks using `jq`.  If any check fails, **ABORT with a clear message** — do NOT write bad data.

#### Complexity ceiling (safety net before marking complete)

```bash
COMPLEXITY=$(jq -r --arg id "$taskId" '.tasks[] | select(.id == $id) | .complexity' "$STATE_FILE" 2>/dev/null)

echo "$COMPLEXITY" | jq -e '
  . as $c |
  if type == "number" and $c == floor and $c >= 1 and $c <= 3
  then true
  else error("complexity must be integer 1..3, got: \($c)")
  end
' > /dev/null 2>&1 || {
  echo "ABORT: task $taskId has complexity '$COMPLEXITY' which violates the 1..3 ceiling."
  echo "Use /replan to split this task before completing it."
  exit 1
}
```

#### Status enum (before writing status update)

```bash
ALLOWED_STATUSES='["pending","in-progress","completed","blocked","cancelled"]'
echo "$newStatus" | jq -r --argjson valid "$ALLOWED_STATUSES" '
  . as $s | $valid | map(select(. == $s)) | length |
  if . > 0 then "ok" else error("invalid status: \($s)") end
' || { echo "ABORT: status '$newStatus' is not in the allowed enum for state.json tasks"; exit 1; }
```

#### Required fields (when writing a new task object — e.g. split tasks from /replan)

```bash
echo "$taskJson" | jq -e '
  ["id","title","description","status","complexity","blockedBy","blocks","subtasks","tags","phase","qualityGate","timestamps"] as $req |
  [ $req[] | select(. as $f | (input? // {}) | has($f) | not) ] as $missing |
  if ($missing | length) > 0
  then error("task missing required fields: \($missing | join(", "))")
  else true end
' > /dev/null 2>&1 || { echo "ABORT: new task object is missing required fields — check state-schema.json"; exit 1; }
```

### Step 4: Record Results

Wrap the state.json mutation in a `flock` block to prevent concurrent sessions from corrupting the file:

```bash
(
  flock -w 10 200 || { echo "index busy, another session holds the lock — retry in a moment"; exit 1; }

  # Write qualityGate results + status update inside the lock
  jq ... "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

) 200>.claude/tasks/.index.lock
```

Update the task's `qualityGate` field in state.json:

```json
{
  "qualityGate": {
    "lint": {
      "status": "pass",
      "timestamp": "2025-01-15T14:30:00.000Z"
    },
    "typecheck": {
      "status": "pass",
      "timestamp": "2025-01-15T14:30:15.000Z"
    },
    "tests": {
      "status": "pass",
      "timestamp": "2025-01-15T14:30:45.000Z",
      "coverage": 94.2
    }
  }
}
```

Or for failures:

```json
{
  "qualityGate": {
    "lint": {
      "status": "fail",
      "timestamp": "2025-01-15T14:30:00.000Z",
      "details": "Error: 3 lint errors found\n  src/models/user.ts:15 - no-unused-vars\n  src/models/user.ts:23 - prefer-const\n  src/services/auth.ts:8 - no-explicit-any"
    },
    "typecheck": {
      "status": "pass",
      "timestamp": "2025-01-15T14:30:15.000Z"
    },
    "tests": {
      "status": "fail",
      "timestamp": "2025-01-15T14:30:45.000Z",
      "details": "FAIL src/models/user.test.ts > User Model > should validate email format\n  Expected: true, Received: false"
    }
  }
}
```

### Step 5: Evaluate Results

#### All Required Checks Pass

1. Update the task's `status` to `"completed"`
2. Set `timestamps.completed` to current ISO timestamp
3. Update the `summary` object in state.json:
   - Decrement `pending` or `inProgress` (depending on previous status)
   - Increment `completed`
4. Check if any tasks that were `blocked` can now be unblocked:
   - For each task with status `blocked` or `pending`:
     - Check if all tasks in its `blockedBy` array are now `completed`
     - If yes, the task is now ready (keep as `pending` but note it's unblocked)
5. Proceed to Step 6

#### Any Required Check Fails

1. Keep the task's `status` as `in-progress`
2. Report failures with details and suggested fixes
3. Do NOT proceed to Step 6 (TODOs regeneration)

### Step 6: Regenerate TODOs.md

If the task was marked as completed, regenerate the TODOs.md file:

1. Read the current state.json
2. Recalculate progress: `completed/total (percentage%)`
3. Update the markdown checklist:
   - Completed tasks: `- [x] **T-001** (complexity: 2) - Task title [DONE]`
   - Pending tasks: `- [ ] **T-002** (complexity: 5) - Task title`
   - Blocked tasks: `- [ ] **T-003** (complexity: 4) - Task title [BLOCKED by T-002]`
   - In-progress tasks: `- [ ] **T-004** (complexity: 3) - Task title [IN PROGRESS]`
4. Update the progress header
5. Write the updated TODOs.md

### Step 7: Check Epic Completion

After updating the task:

1. Check if ALL tasks in the state.json are `completed`
2. If yes:
   a. The epic/spec is fully complete
   b. Read the spec's metadata.json
   c. Update metadata status to `"completed"` and set `completed` timestamp
   d. Use the **index-sync skill** to update BOTH `.claude/specs/index.json` AND `.claude/tasks/index.json` atomically.  NEVER write one index alone.
      - `specId`: the completed spec ID
      - `newStatus`: `"completed"`
      - `newProgress`: `"N/N"` (all tasks done)
   e. The index-sync call MUST happen inside the same `flock` block that wraps the metadata.json write:
      ```bash
      (
        flock -w 10 200 || { echo "index busy — retry"; exit 1; }
        # write metadata.json here
        # then call index-sync jq writes directly inside this block
      ) 200>.claude/tasks/.index.lock
      ```
   f. Report epic completion

## Output

### All Checks Pass

```
Quality Gate Results for T-003
==============================

  complexity:   PASS (3/3 max)
  lint:         PASS
  typecheck:    PASS
  tests:        PASS (coverage: 94.2%)
  tests-added:  YES (2 new test files)

All quality checks passed!

Task T-003 marked as COMPLETED.
Progress: 3/8 tasks (37.5%)

Newly unblocked tasks:
  - T-005 (complexity: 3) - Create search API endpoint
  - T-006 (complexity: 3) - Add search page component

Suggested next task:
  T-005 (complexity: 3) - Create search API endpoint
  (on the critical path, unblocks T-007)

Remember: Commit your completed work (implementation + tests) with /commit before starting the next task.
```

### Some Checks Fail

```
Quality Gate Results for T-003
==============================

  complexity:   PASS (3/3 max)
  lint:         FAIL
  typecheck:    PASS
  tests:        FAIL
  tests-added:  YES (2 new test files)

Quality gate FAILED. Task T-003 remains in-progress.

--- Lint Failures ---
3 errors found:
  src/models/user.ts:15 - no-unused-vars: 'oldPassword' is defined but never used
  src/models/user.ts:23 - prefer-const: 'result' is never reassigned
  src/services/auth.ts:8 - no-explicit-any: Unexpected any

Suggested fixes:
  1. Remove unused 'oldPassword' parameter or prefix with underscore
  2. Change 'let result' to 'const result'
  3. Replace 'any' with proper type (e.g., 'unknown' with type guard)

--- Test Failures ---
1 test failed:
  FAIL test/models/user.test.ts > User Model > should validate email format
    Expected: true
    Received: false

    at test/models/user.test.ts:45:23

Suggested fixes:
  1. Check the email validation regex in User model
  2. The test expects 'user+tag@example.com' to be valid -- ensure the regex supports '+' in local part

Fix the issues above and re-run the quality gate.
```

### Complexity Gate Failure

```
Quality Gate Results for T-009
==============================

  complexity:   FAIL (6/3 max)
  lint:         SKIPPED
  typecheck:    SKIPPED
  tests:        SKIPPED
  tests-added:  SKIPPED

Quality gate FAILED. Task T-009 has complexity 6 (maximum: 3).

This task is too complex for atomic execution and must be decomposed first.
Use /replan to split this task into smaller tasks with complexity ≤ 3.
```

### Epic Completion

```
Quality Gate Results for T-008
==============================

  complexity:   PASS (2/3 max)
  lint:         PASS
  typecheck:    PASS
  tests:        PASS (coverage: 96.1%)
  tests-added:  YES (1 new test file)

All quality checks passed!

Task T-008 marked as COMPLETED.
Progress: 8/8 tasks (100%)

=============================================
  EPIC COMPLETE: SPEC-003 - User Authentication System
=============================================

All 8 tasks have been completed!
Spec SPEC-003 status updated to "completed".
Average complexity: 4.5/10
Total tasks: 8

Congratulations! This spec is fully implemented.
```

## Configurable Checks Reference

The `.claude/task-master.config.json` supports these check types:

```json
{
  "qualityGate": {
    "lint": {
      "command": "pnpm lint",
      "required": true
    },
    "typecheck": {
      "command": "pnpm typecheck",
      "required": true
    },
    "tests": {
      "command": "pnpm test",
      "required": true,
      "maxConcurrency": 2
    },
    "coverage": {
      "threshold": 90,
      "required": false,
      "command": "pnpm test:coverage"
    },
    "custom": {
      "command": "pnpm run my-custom-check",
      "required": false,
      "label": "Custom Check"
    }
  }
}
```

- `command`: The shell command to run
- `required`: If true, this check must pass for the gate to pass. If false, it's informational only.
- `threshold`: For coverage checks, the minimum percentage required
- `label`: Display name for custom checks
- `maxConcurrency`: (tests only) Maximum number of parallel test workers for the concurrency-capped fallback path (Rule B in monorepo detection). Defaults to 2. Applied as `--poolOptions.forks.maxForks=N` for vitest or `--maxWorkers=N` for jest. Has no effect when a scoped package run (Rule A) is used.

If no config file exists, the three standard checks (lint, typecheck, tests) are all required by default.

## Error Handling

- **Task not found**: Report that the task ID does not exist in the state file
- **Task already completed**: Report that the task is already completed and no action is needed
- **Task is blocked**: Report which tasks must complete first, listing their IDs and titles
- **Task is cancelled**: Report that cancelled tasks cannot pass quality gates
- **Command not found**: If a quality check command fails because the tool is not installed, report it as a warning rather than a failure and suggest installing the tool
- **State file not found**: Report the error and ask for the correct path
- **Timeout**: If a check runs longer than 5 minutes, consider it failed with a timeout message
- **Permission error**: If a command fails due to permissions, report the specific permission issue

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Create with `mkdir -p` and check with `[ -d "$DIR" ]`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
- **Pre-Write Validation**: Run invariant checks (Step 3.5) before EVERY state.json write.  ABORT on violation — never write bad data.
- **Index writes**: ALWAYS update both indexes via the `index-sync` skill (Step 7).  NEVER write one index alone.
- **Locking**: ALL index/state mutations (Steps 4 and 7) MUST happen inside a single `flock` block on `.claude/tasks/.index.lock` with a 10-second timeout.  This prevents concurrent sessions from corrupting state.
