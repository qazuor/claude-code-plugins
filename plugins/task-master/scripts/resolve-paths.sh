#!/usr/bin/env bash
# resolve-paths.sh — resolve task-master's filesystem paths AND backend for THIS repo.
#
# THE single source of path/backend resolution. Every command/skill that touches
# the specs or tasks tree must resolve through this script instead of hardcoding
# `.claude/specs` / `.claude/tasks` or assuming the local-index backend.
#
# Config: <repo-root>/.claude/project.config.json, keys under `taskMaster`:
#   - `taskMaster.dir` — the BASE dir that holds specs/tasks (local backend) or the
#     single specs root (linear backend). Default: ".claude".
#   - `taskMaster.backend` — "local" (default) or "linear". Selects the spec
#     registry: local-index (`specs/index.json` + `tasks/index.json`) or Linear
#     issues (registry lives in Linear; this repo only holds spec.md + internal
#     task tracking per spec folder).
#   - `taskMaster.linear.team` / `taskMaster.linear.teamKey` — required when
#     backend is "linear". `team` is the Linear team name (e.g. "Hospeda"),
#     `teamKey` is its issue-ID prefix (e.g. "HOS"). Spec folders are named
#     `<teamKey>-<n>-<slug>` instead of `SPEC-<n>-<slug>`.
#   Note: the config file itself stays under .claude/ (it is tooling config,
#   not a project artifact); only specs/tasks move when taskMaster.dir changes.
#
# Dual-path resolution (per subdir, independently, LOCAL BACKEND ONLY):
#   1. if <configBase>/<subdir> exists on disk  -> use it (migrated / configured)
#   2. else if .claude/<subdir> exists           -> use it (legacy fallback)
#   3. else                                      -> use <configBase>/<subdir>
#                                                   (neither exists yet: fresh writes
#                                                    land at the configured location)
#
# LINEAR BACKEND: there is no global specs/tasks index to lock or dual-resolve —
# the spec registry is Linear itself. Only SPECS_DIR (the single `.specs/`-style
# root holding one folder per spec, each with its own nested `tasks/`) is
# meaningful. TASKS_DIR, SPECS_INDEX, TASKS_INDEX, and LOCK are emitted EMPTY in
# this mode — callers MUST check TM_BACKEND before touching those and resolve a
# per-spec tasks path themselves as "$SPECS_DIR/<spec-folder>/tasks" instead.
#
# STANDALONE_DIR: tasks created via /new-task have no spec/Linear issue, so they
# need a home in BOTH backends independent of the registry question. Resolved as
# "$TASKS_DIR/standalone" (local) or "$SPECS_DIR/_standalone" (linear — leading
# underscore keeps it from ever colliding with a real "<teamKey>-<n>-slug" folder).
# Callers should use this instead of hardcoding either form.
#
# Emits eval-able absolute KEY=value lines (also safe to `source`):
#   TM_BASE, TM_BACKEND, TM_LINEAR_TEAM, TM_LINEAR_TEAM_KEY,
#   SPECS_DIR, TASKS_DIR, SPECS_INDEX, TASKS_INDEX, LOCK, STANDALONE_DIR
#
# Usage:
#   eval "$(bash path/to/resolve-paths.sh)"      # in a script or one-off
#   source path/to/resolve-paths.sh              # to set vars in the current shell
set -uo pipefail

# CLAUDE_PROJECT_DIR (set by Claude Code hooks) takes precedence over git
# discovery: hooks can run with a cwd that isn't the project root.
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CFG="$ROOT/.claude/project.config.json"

TM_BASE=".claude"
TM_BACKEND="local"
TM_LINEAR_TEAM=""
TM_LINEAR_TEAM_KEY=""
if [ -f "$CFG" ] && command -v jq >/dev/null 2>&1; then
  _v="$(jq -r '.taskMaster.dir // empty' "$CFG" 2>/dev/null || true)"
  [ -n "${_v:-}" ] && TM_BASE="$_v"
  _b="$(jq -r '.taskMaster.backend // empty' "$CFG" 2>/dev/null || true)"
  [ -n "${_b:-}" ] && TM_BACKEND="$_b"
  _lt="$(jq -r '.taskMaster.linear.team // empty' "$CFG" 2>/dev/null || true)"
  [ -n "${_lt:-}" ] && TM_LINEAR_TEAM="$_lt"
  _ltk="$(jq -r '.taskMaster.linear.teamKey // empty' "$CFG" 2>/dev/null || true)"
  [ -n "${_ltk:-}" ] && TM_LINEAR_TEAM_KEY="$_ltk"
fi

if [ "$TM_BACKEND" = "linear" ]; then
  if [ -z "$TM_LINEAR_TEAM" ] || [ -z "$TM_LINEAR_TEAM_KEY" ]; then
    echo "resolve-paths.sh: taskMaster.backend is 'linear' but taskMaster.linear.team/teamKey are missing in $CFG" >&2
    exit 1
  fi
  SPECS_DIR="$ROOT/$TM_BASE"
  TASKS_DIR=""
  SPECS_INDEX=""
  TASKS_INDEX=""
  LOCK=""
  STANDALONE_DIR="$SPECS_DIR/_standalone"
else
  # Resolve one subdir (specs|tasks) to an absolute path with dual-path fallback.
  _resolve() {
    local sub="$1"
    if [ -d "$ROOT/$TM_BASE/$sub" ]; then
      echo "$ROOT/$TM_BASE/$sub"
    elif [ -d "$ROOT/.claude/$sub" ]; then
      echo "$ROOT/.claude/$sub"
    else
      echo "$ROOT/$TM_BASE/$sub"
    fi
  }

  SPECS_DIR="$(_resolve specs)"
  TASKS_DIR="$(_resolve tasks)"
  SPECS_INDEX="$SPECS_DIR/index.json"
  TASKS_INDEX="$TASKS_DIR/index.json"
  LOCK="$TASKS_DIR/.index.lock"
  STANDALONE_DIR="$TASKS_DIR/standalone"
fi

cat <<EOF
TM_BASE=$TM_BASE
TM_BACKEND=$TM_BACKEND
TM_LINEAR_TEAM=$TM_LINEAR_TEAM
TM_LINEAR_TEAM_KEY=$TM_LINEAR_TEAM_KEY
SPECS_DIR=$SPECS_DIR
TASKS_DIR=$TASKS_DIR
SPECS_INDEX=$SPECS_INDEX
TASKS_INDEX=$TASKS_INDEX
LOCK=$LOCK
STANDALONE_DIR=$STANDALONE_DIR
EOF
