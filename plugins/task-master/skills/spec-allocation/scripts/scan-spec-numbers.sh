#!/usr/bin/env bash
# Highest existing SPEC-NNN across the repo's spec index, full git history, AND
# the remote's live refs (branches + reservation tags).
#
# Sources (combined, then max):
#   1. <specs-dir>/index.json          — the derived mirror, if present
#   2. `git log --all`                 — catches spec dirs created on branches
#                                        that were never merged (local refs only)
#   3. `git ls-remote <remote>`        — heads AND `spec-reserved-SPEC-*` tags on
#                                        the REMOTE, even when not fetched locally.
#                                        This is what closes the parallel-agent
#                                        race window: a number reserved by another
#                                        machine/worktree is visible immediately,
#                                        before any commit lands locally.
#
# Source 3 is best-effort: if the remote is unreachable (offline, no remote),
# it is skipped silently and the local sources still produce a safe lower bound.
#
# Usage: scan-spec-numbers.sh [specs-dir] [remote]
#   [specs-dir] — default: .claude/specs
#   [remote]    — default: origin
# Output: a single integer (0 if no spec has ever been allocated).
set -uo pipefail

SPECS_DIR="${1:-.claude/specs}"
REMOTE="${2:-origin}"
INDEX="${SPECS_DIR}/index.json"

collect() {
  # Source 1 — the index file (raw grep, schema-agnostic).
  # `|| true` is required: a present-but-SPEC-less index makes grep exit 1, which
  # under `set -e` would abort collect() before later sources ever run.
  if [ -f "$INDEX" ]; then
    grep -oE "SPEC-[0-9]+" "$INDEX" 2>/dev/null || true
  fi
  # Source 2 — every LOCAL branch's history, across ALL paths. Unfiltered (not
  # scoped to $SPECS_DIR) so the scan stays correct after the specs dir MOVES
  # between locations (e.g. .claude/specs -> .qtm/specs): the old location's
  # history would otherwise be invisible under the new path and the scan would
  # under-count. Over-counting (a stray SPEC-NNN in some other filename) is safe —
  # it only skips a number; under-counting would hand out a number that collides.
  git log --all --name-only --format="" 2>/dev/null \
    | grep -oE "SPEC-[0-9]+" 2>/dev/null || true
  # Source 3 — the REMOTE's live refs: branch names (spec/SPEC-NNN-...) and the
  # atomic reservation tags (spec-reserved-SPEC-NNN). ls-remote hits the network
  # but does NOT require a fetch, so it sees work pushed by other agents that has
  # not reached this clone yet. Best-effort: any failure (offline / no remote)
  # is swallowed and the scan proceeds on local sources only.
  git ls-remote --heads --tags "$REMOTE" 2>/dev/null \
    | grep -oE "SPEC-[0-9]+" 2>/dev/null || true
}

# Extract the numeric suffix, drop leading zeros so `sort -n` compares numerically,
# keep only clean integers, take the largest. Trailing `|| true` covers the
# no-specs case: an empty pipeline exits 1 under pipefail, which would otherwise
# abort the script before the `echo` instead of reporting 0.
MAX=$(collect | grep -oE "[0-9]+$" | sed 's/^0*//' | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
echo "${MAX:-0}"
