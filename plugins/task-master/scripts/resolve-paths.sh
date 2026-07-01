#!/usr/bin/env bash
# resolve-paths.sh — resolve task-master's filesystem paths for THIS repo.
#
# THE single source of path resolution. Every command/skill that touches the
# specs or tasks tree must resolve through this script instead of hardcoding
# `.claude/specs` / `.claude/tasks`.
#
# Config: <repo-root>/.claude/project.config.json, key `taskMaster.dir`
#   (the BASE dir that holds specs/ and tasks/). Default: ".claude".
#   Note: the config file itself stays under .claude/ (it is tooling config,
#   not a project artifact); only specs/tasks move when taskMaster.dir changes.
#
# Dual-path resolution (per subdir, independently):
#   1. if <configBase>/<subdir> exists on disk  -> use it (migrated / configured)
#   2. else if .claude/<subdir> exists           -> use it (legacy fallback)
#   3. else                                      -> use <configBase>/<subdir>
#                                                   (neither exists yet: fresh writes
#                                                    land at the configured location)
#
# Emits eval-able absolute KEY=value lines (also safe to `source`):
#   SPECS_DIR, TASKS_DIR, SPECS_INDEX, TASKS_INDEX, LOCK, TM_BASE
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
if [ -f "$CFG" ] && command -v jq >/dev/null 2>&1; then
  _v="$(jq -r '.taskMaster.dir // empty' "$CFG" 2>/dev/null || true)"
  [ -n "${_v:-}" ] && TM_BASE="$_v"
fi

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

cat <<EOF
TM_BASE=$TM_BASE
SPECS_DIR=$SPECS_DIR
TASKS_DIR=$TASKS_DIR
SPECS_INDEX=$SPECS_INDEX
TASKS_INDEX=$TASKS_INDEX
LOCK=$LOCK
EOF
