---
name: index-sync
description: Atomically updates both .claude/specs/index.json and .claude/tasks/index.json for a given spec, detects and repairs pre-existing drift between them, and enforces write invariants before any mutation
---

# Index Sync

## Purpose

Ensure `.claude/specs/index.json` and `.claude/tasks/index.json` remain consistent at all times.
Every status/progress write to either index MUST go through this skill — never write one index alone.

## Why Two Indexes Exist

- `specs/index.json` — source of truth for spec lifecycle status (`draft`, `approved`, `in-progress`, `completed`, `cancelled`, `reserved`, `merged`, `obsolete`)
- `tasks/index.json` — mirrors spec status and carries task-level progress (`progress`, task counts).  Its vocabulary is `pending`, `in-progress`, `completed`, `cancelled`, `draft`, `reserved`, `merged`, `obsolete` — the same as the specs index except `approved` (which maps to `pending`) and the extra `pending` value.

They drift when one is written without the other.  This skill closes that gap.

## Inputs

You will receive:

1. **specId** — e.g. `"SPEC-001"` (required)
2. **newStatus** — the target status for both indexes.  Must be one of: `pending`, `in-progress`, `completed`, `cancelled`, `draft`, `reserved`, `merged`, `obsolete` (tasks index) / `draft`, `approved`, `in-progress`, `completed`, `cancelled`, `reserved`, `merged`, `obsolete` (specs index).  Pass `null` to skip status update (progress-only write).
3. **newProgress** — string in `"N/M"` format, e.g. `"4/10"` (optional — omit or pass `null` to skip progress update)
4. **specsIndexPath** — absolute path to `.claude/specs/index.json` (default: `.claude/specs/index.json`)
5. **tasksIndexPath** — absolute path to `.claude/tasks/index.json` (default: `.claude/tasks/index.json`)

## Process

### Step 0: Pre-Write Validation (Invariant Checks)

Before ANY write, validate the requested mutation.  These checks use `jq` only.  If any check fails, **ABORT with a clear error message** — do NOT write bad data.

#### 0a. Status enum check

If `newStatus` is provided, verify it is one of the allowed values:

```bash
# Allowed values for tasks/index.json epics
TASK_STATUSES="pending in-progress completed cancelled draft reserved merged obsolete"
# Allowed values for specs/index.json
SPEC_STATUSES="draft approved in-progress completed cancelled reserved merged obsolete"

# newStatus must be valid in AT LEAST ONE vocabulary.  `pending` is task-only
# and `approved` is spec-only, so requiring membership in BOTH would reject those
# legitimate values.  Accept if it appears in either set.
if ! echo "$TASK_STATUSES $SPEC_STATUSES" | grep -qw "$newStatus"; then
  echo "ABORT: invalid status '$newStatus' — not in tasks ($TASK_STATUSES) or specs ($SPEC_STATUSES) vocabulary"; exit 1
fi
```

#### 0b. Progress format check

If `newProgress` is provided, verify format `N/M` with integer N ≤ M:

```bash
# jq invariant check
echo "$newProgress" | jq -Rr '
  split("/") |
  if length != 2 then error("progress must be N/M format") else . end |
  (.[0] | tonumber) as $n |
  (.[1] | tonumber) as $m |
  if $n < 0 or $m < 0 then error("progress values must be non-negative") else . end |
  if $n > $m then error("completed (\($n)) cannot exceed total (\($m))") else "ok" end
' 2>&1 | grep -q "^ok$" || { echo "ABORT: invalid progress format '$newProgress' (must be N/M with N<=M)"; exit 1; }
```

#### 0c. Spec directory existence check

When writing a new epic entry, confirm `.claude/specs/{slug}/` exists on disk.  Skip this check for updates to existing entries.

```bash
SPEC_DIR=".claude/specs/${specSlug}"
[ -d "$SPEC_DIR" ] || { echo "ABORT: spec directory '$SPEC_DIR' does not exist — cannot create index entry for a non-existent spec"; exit 1; }
```

#### 0d. Required fields check (for new entries only)

When adding a new entry, verify all required fields are provided: `specId`, `title`, `status`, `path`.

### Step 1: Detect Pre-Existing Drift

Read both index files and compare the entry for `specId`.  Report any disagreements BEFORE applying the new write.

```bash
SPECS_INDEX=".claude/specs/index.json"
TASKS_INDEX=".claude/tasks/index.json"

# Extract current values from both indexes (empty string if entry not found)
SPEC_STATUS=$(jq -r --arg id "$specId" '
  .specs // [] | map(select(.specId == $id)) | first | .status // ""
' "$SPECS_INDEX" 2>/dev/null)

TASK_STATUS=$(jq -r --arg id "$specId" '
  .epics // [] | map(select(.specId == $id)) | first | .status // ""
' "$TASKS_INDEX" 2>/dev/null)

TASK_PROGRESS=$(jq -r --arg id "$specId" '
  .epics // [] | map(select(.specId == $id)) | first | .progress // ""
' "$TASKS_INDEX" 2>/dev/null)
```

If `SPEC_STATUS != TASK_STATUS` and both are non-empty, report:

```
⚠ Drift detected for SPEC-NNN before write:
  specs/index.json  status: "<old-spec-status>"
  tasks/index.json  status: "<old-task-status>"
  Reconciling: specs/index.json is authoritative — tasks/index.json will be updated.
```

Trust `specs/index.json` as authoritative on status disagreements.  The new write then supersedes both.

### Step 2: Compute the Status Mapping

The two indexes share almost the same vocabulary.  The mapping is **identity** —
the tasks index mirrors the spec status exactly — with a **single exception**:
`approved` (a specs-only value) maps to `pending` in the tasks index.

| Canonical (specs index)  | Tasks index equivalent |
|--------------------------|------------------------|
| `draft`                  | `draft`                |
| `approved`               | `pending`              |
| `reserved`               | `reserved`             |
| `in-progress`            | `in-progress`          |
| `completed`              | `completed`            |
| `merged`                 | `merged`               |
| `cancelled`              | `cancelled`            |
| `obsolete`               | `obsolete`             |

When `newStatus` is `approved`, write `pending` into `tasks/index.json`.
Every other value is written as-is to both indexes (identity mapping).

### Step 3: Update specs/index.json

Use a single atomic `jq` rewrite (read → transform → write back).

```bash
# Wrap in flock to prevent concurrent writes (see Concurrency section below)
(
  flock -w 10 200 || { echo "ABORT: index busy, another session holds the lock — retry in a moment"; exit 1; }

  SPECS_INDEX=".claude/specs/index.json"

  # Build the patch object (only include fields that are being updated)
  jq_status_patch=""
  [ -n "$newStatus" ] && jq_status_patch="| if .specId == \"$specId\" then .status = \"$newStatus\" else . end"

  jq --arg id "$specId" \
     --arg status "$newStatus" \
     '
     .specs |= map(
       if .specId == $id then
         (if ($status != "" and $status != "null") then .status = $status else . end)
       else . end
     )
     ' "$SPECS_INDEX" > "${SPECS_INDEX}.tmp" && mv "${SPECS_INDEX}.tmp" "$SPECS_INDEX"

) 200>.claude/tasks/.index.lock
```

If the entry does not exist in `specs/index.json` yet (new spec creation), append it instead of updating.

### Step 4: Update tasks/index.json

Apply the mapped status and/or progress to `tasks/index.json`:

```bash
(
  flock -w 10 200 || { echo "ABORT: index busy, another session holds the lock — retry in a moment"; exit 1; }

  TASKS_INDEX=".claude/tasks/index.json"
  TASK_STATUS_VAL="$mappedTaskStatus"   # computed from Step 2 mapping
  PROGRESS_VAL="$newProgress"           # may be empty/null

  jq --arg id "$specId" \
     --arg status "$TASK_STATUS_VAL" \
     --arg progress "$PROGRESS_VAL" \
     '
     .epics |= map(
       if .specId == $id then
         (if ($status != "" and $status != "null") then .status = $status else . end) |
         (if ($progress != "" and $progress != "null") then .progress = $progress else . end)
       else . end
     )
     ' "$TASKS_INDEX" > "${TASKS_INDEX}.tmp" && mv "${TASKS_INDEX}.tmp" "$TASKS_INDEX"

) 200>.claude/tasks/.index.lock
```

### Step 5: Verify Write

After both writes complete, re-read both files and confirm the entries match expectations:

```bash
FINAL_SPEC_STATUS=$(jq -r --arg id "$specId" '.specs[] | select(.specId == $id) | .status' "$SPECS_INDEX" 2>/dev/null)
FINAL_TASK_STATUS=$(jq -r --arg id "$specId" '.epics[] | select(.specId == $id) | .status' "$TASKS_INDEX" 2>/dev/null)
FINAL_TASK_PROGRESS=$(jq -r --arg id "$specId" '.epics[] | select(.specId == $id) | .progress' "$TASKS_INDEX" 2>/dev/null)
```

If any value does not match what was written, report an error.

### Step 6: Report

```
Index sync complete for SPEC-NNN
  specs/index.json  status: <new-spec-status>
  tasks/index.json  status: <new-task-status>  progress: <new-progress>
  [drift reconciled: <old-spec-status> → <new-spec-status>]   (only if drift was found in Step 1)
```

## Concurrency: flock Pattern

ALL index mutations — both in this skill and in every caller — MUST be wrapped in a single `flock` block:

```bash
(
  flock -w 10 200 || { echo "index busy, another session holds the lock — retry in a moment"; exit 1; }
  # ALL reads + transforms + writes happen INSIDE this block
  # Never split the read and the write outside the lock
) 200>.claude/tasks/.index.lock
```

- **Lock file**: `.claude/tasks/.index.lock`  (create on first use; do NOT commit it — add to `.gitignore` if one exists)
- **Timeout**: 10 seconds (`-w 10`).  If another session holds the lock for longer than 10 s, it is a bug — abort rather than deadlock.
- **Auto-release**: `flock` releases automatically when the subshell exits, even on crash.  No stale-lock handling needed.
- **Single block**: Read, transform, and write MUST all happen inside one `flock` block.  Never read outside and write inside — that leaves a TOCTOU window.

## Pre-Write Validation jq Snippets (Reference)

These can be copy-pasted wherever a write is about to happen:

### Status enum check (jq)

```bash
VALID_TASK_STATUSES='["pending","in-progress","completed","cancelled","draft","reserved","merged","obsolete"]'
echo "$status" | jq -r --argjson valid "$VALID_TASK_STATUSES" '
  . as $s | $valid | map(select(. == $s)) | length > 0 |
  if . then "ok" else error("invalid status: \($s)") end
' || { echo "ABORT: status '$status' not in allowed enum"; exit 1; }
```

### Complexity ceiling check (jq) — for state.json writes

```bash
# Verify before writing a task: complexity must be integer 1..3
echo "$complexity" | jq '
  if type == "number" and . == floor and . >= 1 and . <= 3
  then "ok"
  else error("complexity must be integer 1..3, got: \(.)") end
' || { echo "ABORT: task complexity '$complexity' violates 1..3 ceiling — use /replan to split before writing"; exit 1; }
```

### Required fields check (jq) — for new task entries

```bash
# Verify task object has all required fields before appending to state.json
echo "$taskJson" | jq '
  ["id","title","status","complexity","blockedBy","blocks","subtasks","tags","phase","qualityGate","timestamps"] as $required |
  ($required | map(select(. as $f | (input? // {}) | has($f) | not))) as $missing |
  if ($missing | length) > 0
  then error("task missing required fields: \($missing | join(", "))")
  else "ok" end
' || { echo "ABORT: task is missing required fields"; exit 1; }
```

## Error Handling

- **Lock timeout**: Print `"ABORT: index busy — another session holds .index.lock after 10s timeout. Check for crashed processes."` and exit non-zero. Do NOT proceed with the write.
- **File not found**: If either index does not exist, create it with empty structure before writing. Never fail silently.
- **jq parse error**: If either index is not valid JSON, report `"ABORT: <path> is not valid JSON — manual repair required"` and exit. Do NOT overwrite corrupted data.
- **Partial write**: If the `specs/index.json` write succeeds but the `tasks/index.json` write fails, report the partial state and instruct the user to re-run index-sync to complete the repair.

## When to Use This Skill

Every place that writes a status or progress to either index MUST call this skill instead of writing one index alone:

| Caller | Trigger |
|--------|---------|
| `commands/spec.md` Step 4d + Step 5c | New spec entry + initial task index entry |
| `skills/spec-generator/SKILL.md` Step 9 | New spec entry in specs/index.json |
| `skills/task-from-spec/SKILL.md` Step 7 | New epic entry in tasks/index.json |
| `commands/next-task.md` Step 4c | Epic status → `in-progress` on first task start |
| `commands/replan.md` Step 3d | Epic progress update after replan |
| `skills/quality-gate/SKILL.md` Step 7 | Epic/spec status → `completed` |

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Create with `mkdir -p` and check with `[ -d "$DIR" ]`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
- **Lock**: ALL index/state mutations MUST happen inside a single `flock` block on `.claude/tasks/.index.lock`.
