#!/usr/bin/env bash
# Highest existing SPEC-NNN across the repo's spec index + full git history.
#
# Sources (combined, then max):
#   1. <specs-dir>/index.json        — the derived mirror, if present
#   2. `git log --all` over <specs-dir> — catches spec dirs created on branches
#                                          that were never merged
#
# Usage: scan-spec-numbers.sh [specs-dir]   (default: .claude/specs)
# Output: a single integer (0 if no spec has ever been allocated).
set -euo pipefail

SPECS_DIR="${1:-.claude/specs}"
INDEX="${SPECS_DIR}/index.json"

collect() {
  # Source 1 — the index file (raw grep, schema-agnostic).
  # `|| true` is required: a present-but-SPEC-less index makes grep exit 1, which
  # under `set -e` would abort collect() before Source 2 ever runs.
  if [ -f "$INDEX" ]; then
    grep -oE "SPEC-[0-9]+" "$INDEX" 2>/dev/null || true
  fi
  # Source 2 — every branch's history, across ALL paths. Unfiltered (not scoped to
  # $SPECS_DIR) so the scan stays correct after the specs dir MOVES between
  # locations (e.g. .claude/specs -> .qtm/specs): the old location's history would
  # otherwise be invisible under the new path and the scan would under-count.
  # Over-counting (a stray SPEC-NNN in some other filename) is safe — it only skips
  # a number; under-counting would hand out a number that collides.
  git log --all --name-only --format="" 2>/dev/null \
    | grep -oE "SPEC-[0-9]+" 2>/dev/null || true
}

# Extract the numeric suffix, drop leading zeros so `sort -n` compares numerically,
# keep only clean integers, take the largest. Trailing `|| true` covers the
# no-specs case: an empty pipeline exits 1 under pipefail, which would otherwise
# abort the script before the `echo` instead of reporting 0.
MAX=$(collect | grep -oE "[0-9]+$" | sed 's/^0*//' | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
echo "${MAX:-0}"
