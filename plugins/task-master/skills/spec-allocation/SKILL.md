---
name: spec-allocation
description: >-
  Allocate the next spec identifier without collisions across parallel worktrees,
  branches, and machines. On the LOCAL backend (default): a git + index scan plus
  an OPTIONAL engram registry, allocating SPEC-NNN. On the LINEAR backend: creates
  the Linear issue directly and uses its returned ID (e.g. HOS-12) — Linear's own
  atomic issue creation IS the collision lock, no scan/tag/engram needed. Trigger
  BEFORE creating any spec directory (resolved via `scripts/resolve-paths.sh`):
  when a new spec is requested via `/spec`, a direct ask, or any spec-creation flow.
---

# Spec allocation skill

Hands out the next spec identifier and reserves it so two parallel sessions
(different terminals / worktrees / machines) never grab the same one.

This skill is the **single source of the allocation protocol**. `/spec` and any
other spec-creation flow delegate here instead of reimplementing the scan.

## When to run

Run the **Allocate** flow exactly once, BEFORE creating the spec directory, on any
of: `/spec`, "create a spec for X", picking up a spec that has no number yet. On
the LOCAL backend, also run the **Activate** flow on the first commit that touches
the spec dir, and the **Status** flow when a spec ships or is retired (on the
LINEAR backend, these are superseded by `index-sync` — see below).

## Config

> This skill ships inside the task-master plugin (`plugins/task-master/skills/spec-allocation/`)
> and is symlinked to `~/.claude/skills/spec-allocation` so it can be invoked globally,
> outside `/spec`.

First, resolve the backend: `eval "$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-paths.sh")"` and check `$TM_BACKEND`.

- `TM_BACKEND=linear` → run **Flow 1 (Linear)** below. `$TM_LINEAR_TEAM` /
  `$TM_LINEAR_TEAM_KEY` are required (resolve-paths.sh already validates they're
  set and aborts otherwise).
- `TM_BACKEND=local` (default) → run **Flow 1 (Local)** below, unchanged. Optional
  overrides in `<repo-root>/.claude/project.config.json`:
  - `specAllocation.projectName` — registry namespace (default: `basename` of the repo root).
  - `specAllocation.specsDir` — where spec dirs live (default: resolved from `scripts/resolve-paths.sh`; legacy fallback is `.claude/specs`).

Never invent config silently; if a value is missing, use the default.

## Flow 1 (Linear) — Allocate via Linear issue creation

### Inputs

- `title` — the spec title (human-readable).
- `slug` — URL-friendly form of the title (lowercase, hyphens, max 50 chars). The
  caller derives it from `title` and passes it in.
- `labels` — optional extra labels beyond `kind-spec` (e.g. area-* labels the
  caller has already inferred from the request).

### Steps

1. `ToolSearch` with query `select:mcp__linear__save_issue` if not already loaded.
2. Create the issue:
   ```
   mcp__linear__save_issue({
     title: "Implement spec: <title>",
     team: "$TM_LINEAR_TEAM",
     labels: ["kind-spec", ...extra labels]
   })
   ```
3. The response's `id` field (e.g. `"HOS-12"`) IS the allocated identifier. Linear's
   issue creation is already server-side atomic — there is no scan, no git tag, and
   no engram cross-check to do here. This mirrors exactly why the local backend
   trusts the git-tag push over engram (see "Why not engram for the lock" in Flow 1
   Local below): a single authoritative atomic-create call beats any client-side
   scan-then-reserve dance.

### Output

Return the Linear identifier (e.g. `HOS-12`) and the directory path
`<SPECS_DIR>/HOS-12-<slug>/` (using `$TM_LINEAR_TEAM_KEY` as the prefix, not the
literal string `HOS`). ONLY THEN does the caller create the directory.

### Status transitions in Linear mode

Flow 2 (Activate) and Flow 3 (Status transitions) below are LOCAL-BACKEND ONLY.
On the Linear backend, every status change (reserved→active, active→completed,
etc.) is just a normal spec-lifecycle event — call the `index-sync` skill, which
branches to its own Linear-mode process and updates the issue's state directly.
There is no separate allocation-registry bookkeeping to maintain, because Linear
already IS that registry.

## Flow 1 (Local) — Allocate via git+index scan

### Inputs

- `title` — the spec title (human-readable).
- `slug` — URL-friendly form of the title (lowercase, hyphens, max 50 chars). The
  caller derives it from `title` and passes it in.

Determine `PROJECT` (config or repo-root basename) and `SPECS_DIR` using the path resolver:

```bash
eval "$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-paths.sh")"
# SPECS_DIR is now set to the resolved absolute path
```

### Source 1 + 2 + 3 — index + git + remote scan (ALWAYS run)

Run the scan script with its FULL path (it lives in THIS skill's `scripts/` dir,
which is NOT the same as `${CLAUDE_PLUGIN_ROOT}/scripts/` where `resolve-paths.sh`
lives — passing the bare `scripts/...` to bash from the wrong cwd is what made
earlier runs silently fall back to an improvised scan):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/spec-allocation/scripts/scan-spec-numbers.sh" "$SPECS_DIR"
```

It returns the highest existing SPEC number across (1) the repo's `index.json`,
(2) `git log --all` (local branches, incl. never-merged dirs), and (3)
`git ls-remote` — the remote's branch heads AND `spec-reserved-SPEC-*` tags, even
when not fetched locally. Source 3 is what surfaces numbers other agents reserved
on other machines/worktrees before any commit reaches this clone. Let `SCAN_MAX`
be its output.

`CANDIDATE = SCAN_MAX + 1`.

### Reserve the number — ATOMIC git tag (PRIMARY, the real lock)

This is the step that actually prevents collisions. Run:

```bash
RESERVED=$(bash "${CLAUDE_PLUGIN_ROOT}/skills/spec-allocation/scripts/reserve-spec-number.sh" "$CANDIDATE")
RC=$?
```

The script pushes a `spec-reserved-SPEC-N` tag to the remote. Pushing a tag that
already exists fails server-side (tags are immutable), so this is a **distributed
atomic compare-and-set**: it tries `CANDIDATE`, and on any lost race it advances to
`CANDIDATE+1`, `+2`, ... until a push succeeds, then prints the number it actually
secured. **Use `$RESERVED` as the allocated number — it may be higher than
`$CANDIDATE`** if another agent reserved in the gap between your scan and your push.

- `RC=0` → `$RESERVED` is yours; the tag is permanent (no release step — it
  guarantees the number is never reused, mirroring the `archived` rule).
- `RC=3` → remote unreachable. Fall back to scan-only: use `$CANDIDATE`, and warn
  loudly `[spec-alloc] remote unreachable — number not atomically reserved; risk of
  collision if another agent is allocating concurrently.` Never block on this.

> Why not engram for the lock: engram is a semantic store with last-writer-wins
> upserts and non-deterministic recall. Two parallel agents could both "reserve"
> the same number and silently clobber each other (this is exactly the SPEC-259
> double-allocation that motivated this change). The remote ref namespace is a
> single source of truth with atomic server-side ref creation — the correct lock.

### Engram cross-check (OPTIONAL, informational only)

Engram is no longer the lock — the tag above is. Engram is kept ONLY as a
human-readable audit trail and is best-effort. If the MCP tools are unavailable,
skip silently. After a successful tag reservation, record it:

```
mem_save(
  title: "Reserve SPEC-<RESERVED> for <slug>",
  type: "decision",
  scope: "project",
  topic_key: "spec-registry/<PROJECT>",
  content: {
    "lastNumber": <RESERVED>,
    "allocations": [ ...existing entries...,
      { "specId": "SPEC-<RESERVED>", "slug": "<slug>", "status": "reserved",
        "reservedAt": "<ISO>", "branch": "<current branch>", "worktree": "<abs path>" }
    ]
  }
)
```

Read the full existing content first and APPEND to `allocations` — never drop prior
entries. Do NOT rely on engram recall to detect collisions; the tag push already
did. A failure here is non-fatal and never changes the allocated number.

### Output

Return the zero-padded number (e.g. `042`) and the directory path
`<SPECS_DIR>/SPEC-<CANDIDATE>-<slug>/`. The slug is URL-friendly (lowercase, hyphens,
max 50 chars). ONLY THEN does the caller create the directory.

## Flow 2 — Activate (LOCAL BACKEND ONLY, on first commit touching the spec dir)

Upsert the same `spec-registry/<PROJECT>` entry, flipping that spec's allocation from
`reserved` to `active`. This prevents stale-reservation accumulation. Skip silently
if engram is unavailable.

## Flow 3 — Status transitions (LOCAL BACKEND ONLY)

Upsert the allocation entry (engram-optional) on lifecycle changes:

- `reserved` → `active` — first commit references the spec.
- `active` → `completed` — spec ships (PR merged, all tasks closed).
- `active` → `archived` — spec intentionally retired (entry STAYS so the number is never reused).
- `reserved` → `abandoned` — no commit within 14 days (decided at the stale-reservation check).
- `*` → `renumbered` — preserve `renumberedFrom` and `renumberedReason` on the entry.

## Conflict resolution

- engram and the scan disagree on the max → take `max(both) + 1`, warn, save the new max.
- two worktrees reserve at once → engram's upsert makes the first writer win; the second
  sees its number already taken on read-back and must pick the next one.
- a spec dir exists but has no engram entry → BACKFILL it into `allocations`
  (`status: active`, `inFilesystem: true`) before allocating the next number.

## Failure modes

- engram unreachable → fall back to git+index scan, warn loudly, continue. The scan
  alone is a safe lower bound; engram only tightens the cross-session guarantee.
- `index.json` disagrees with engram → trust engram, treat `index.json` as a derived
  mirror to regenerate. NEVER hand-edit `index.json` to "fix" a number.

## What this skill does NOT do

It allocates the identifier and maintains the registry only. Creating the spec dir,
writing `spec.md` / `metadata.json`, and generating tasks stay with the caller. On
the Linear backend, it also does not check for duplicate/overlapping specs before
creating the issue — that's `overlap-detector`'s job, run before this skill.
