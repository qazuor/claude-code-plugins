---
name: spec-allocation
description: >-
  Allocate the next SPEC-NNN number without collisions across parallel worktrees,
  branches, and machines. Uses a git + index scan plus an OPTIONAL engram registry
  (best-effort — falls back to git+index if engram is unavailable). Trigger BEFORE
  creating any `.claude/specs/SPEC-NNN-<slug>/` directory: when a new spec is
  requested via `/spec`, a direct ask, or any spec-creation flow. Works in any
  project; the repo's `index.json` is a derived mirror, never the source of truth.
---

# Spec allocation skill

Hands out the next `SPEC-NNN` number and reserves it so two parallel sessions
(different terminals / worktrees / machines) never grab the same one.

This skill is the **single source of the allocation protocol**. `/spec` and any
other spec-creation flow delegate here instead of reimplementing the scan.

## When to run

Run the **Allocate** flow exactly once, BEFORE creating the spec directory, on any
of: `/spec`, "create a spec for X", picking up a spec that has no number yet. Run
the **Activate** flow on the first commit that touches the spec dir, and the
**Status** flow when a spec ships or is retired.

## Config (optional)

> This skill ships inside the task-master plugin (`plugins/task-master/skills/spec-allocation/`)
> and is symlinked to `~/.claude/skills/spec-allocation` so it can be invoked globally,
> outside `/spec`.

Defaults work with zero config. To override, read `<repo-root>/.claude/project.config.json`:

- `specAllocation.projectName` — registry namespace (default: `basename` of the repo root).
- `specAllocation.specsDir` — where spec dirs live (default: `.claude/specs`).

Never invent config silently; if a value is missing, use the default.

## Flow 1 — Allocate (mandatory before creating a spec dir)

### Inputs

- `title` — the spec title (human-readable).
- `slug` — URL-friendly form of the title (lowercase, hyphens, max 50 chars). The
  caller derives it from `title` and passes it in.

Determine `PROJECT` (config or repo-root basename) and `SPECS_DIR` (config or `.claude/specs`).

### Source 1 + 2 — git + index scan (ALWAYS run)

Run `scripts/scan-spec-numbers.sh "$SPECS_DIR"`. It returns the highest existing
SPEC number across the repo's `index.json` AND `git log --all` (catches dirs created
on never-merged branches). Let `SCAN_MAX` be its output.

`CANDIDATE = SCAN_MAX + 1`.

### Source 3 — engram registry (OPTIONAL, best-effort)

> **Engram is optional.** If the engram MCP tools are not available, skip this
> source, log one line, and proceed with the scan candidate. NEVER block spec
> creation on engram.

1. `mem_search(query: "spec-registry/<PROJECT>", project: "<PROJECT>")`.
2. If found, `mem_get_observation(id: <id>)` and parse `lastNumber`. Let `ENGRAM_MAX = lastNumber`.
3. `CANDIDATE = max(CANDIDATE, ENGRAM_MAX + 1)`.
4. If not found, `ENGRAM_MAX = 0` — keep the scan candidate.
5. On any error / unavailable tools, warn and continue:
   `[spec-alloc] engram unavailable — using index.json + git scan only (SPEC-NNN).`

### Stale-reservation check (only if the registry was found)

If `allocations` contains an entry with `status: reserved` older than 14 days, ask the
user whether to **resume** it (reuse that number+slug), **abandon** it (mark
`abandoned`, do not reuse the number), or **skip** (ignore and allocate fresh).
Never silently reuse or recycle a reserved number.

### Reserve the number (OPTIONAL — only if engram is available)

```
mem_save(
  title: "Reserve SPEC-<CANDIDATE> for <slug>",
  type: "decision",
  scope: "project",
  topic_key: "spec-registry/<PROJECT>",
  content: {
    "lastNumber": <CANDIDATE>,
    "allocations": [ ...existing entries...,
      { "specId": "SPEC-<CANDIDATE>", "slug": "<slug>", "status": "reserved",
        "reservedAt": "<ISO>", "branch": "<current branch>", "worktree": "<abs path>" }
    ]
  }
)
```

Read the full existing content first and APPEND to `allocations` — never drop prior
entries. The `topic_key` upserts, so the latest save wins.

**Read-back (makes "first writer wins" real):** after saving, re-read the registry
(`mem_search` + `mem_get_observation`). If another session already reserved your
`CANDIDATE` number between your scan and your save, increment to the next free number
and reserve again. Without this step the second concurrent writer never notices the
collision. Skip silently if engram is unavailable.

### Output

Return the zero-padded number (e.g. `042`) and the directory path
`<SPECS_DIR>/SPEC-<CANDIDATE>-<slug>/`. The slug is URL-friendly (lowercase, hyphens,
max 50 chars). ONLY THEN does the caller create the directory.

## Flow 2 — Activate (on first commit touching the spec dir)

Upsert the same `spec-registry/<PROJECT>` entry, flipping that spec's allocation from
`reserved` to `active`. This prevents stale-reservation accumulation. Skip silently
if engram is unavailable.

## Flow 3 — Status transitions

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

It allocates the number and maintains the registry only. Creating the spec dir,
writing `spec.md` / `metadata.json`, and generating tasks stay with the caller.
