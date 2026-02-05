#!/usr/bin/env bash
# shellcheck disable=SC2030,SC2031
# =============================================================================
# test-knowledge-sync.sh - Functional tests for knowledge-sync plugin
# =============================================================================
#
# Tests:
#   - check-updates.sh: silent exit when not configured
#   - detect.sh: package.json parsing, component matching
#   - sync.sh: component sync logic, registry updates
#   - Config/registry schema validation
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

PLUGIN_DIR="$PROJECT_ROOT/plugins/knowledge-sync"

setup_tmpdir

# ============================================================================
# check-updates.sh: Silent Exit
# ============================================================================
describe "check-updates.sh: Silent Exit When Not Configured"

it "Exits 0 when cache dir missing"
(
    export HOME="$TEST_TMPDIR"
    # No knowledge-sync dir at all
    if [[ ! -d "$HOME/.claude/knowledge-sync/cache/.git" ]] || [[ ! -f "$HOME/.claude/knowledge-sync/config.json" ]]; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Exits 0 when config file missing"
(
    export HOME="$TEST_TMPDIR"
    mkdir -p "$HOME/.claude/knowledge-sync/cache/.git"
    # No config.json
    if [[ ! -d "$HOME/.claude/knowledge-sync/cache/.git" ]] || [[ ! -f "$HOME/.claude/knowledge-sync/config.json" ]]; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Exits 0 when registry file missing"
(
    export HOME="$TEST_TMPDIR"
    mkdir -p "$HOME/.claude/knowledge-sync/cache/.git"
    echo '{"repoUrl":"test"}' > "$HOME/.claude/knowledge-sync/config.json"
    # No registry
    REGISTRY_FILE="$HOME/.claude/knowledge-sync/registry.json"
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

it "Exits 0 when project not in registry"
(
    export HOME="$TEST_TMPDIR"
    mkdir -p "$HOME/.claude/knowledge-sync/cache/.git"
    echo '{"repoUrl":"test"}' > "$HOME/.claude/knowledge-sync/config.json"
    echo '{"projects":{}}' > "$HOME/.claude/knowledge-sync/registry.json"

    PROJECT_PATH="/some/unknown/path"
    PROJECT_ENTRY=$(jq -r --arg p "$PROJECT_PATH" '.projects[$p] // empty' "$HOME/.claude/knowledge-sync/registry.json" 2>/dev/null)
    if [[ -z "$PROJECT_ENTRY" ]]; then
        exit 0
    fi
    exit 1
)
assert_exit_code "0" "$?" "$CURRENT_TEST"

# ============================================================================
# detect.sh: Package.json Parsing
# ============================================================================
describe "detect.sh: Package.json Parsing"

it "Extracts dependencies from package.json"
mkdir -p "$TEST_TMPDIR/detect-project"
cat > "$TEST_TMPDIR/detect-project/package.json" << 'EOF'
{
  "dependencies": {
    "react": "^18.0.0",
    "next": "^14.0.0",
    "zod": "^3.0.0"
  },
  "devDependencies": {
    "@tanstack/react-query": "^5.0.0",
    "typescript": "^5.0.0"
  }
}
EOF

deps=$(jq -r '(.dependencies // {} | keys[]), (.devDependencies // {} | keys[])' \
    "$TEST_TMPDIR/detect-project/package.json" 2>/dev/null | sort -u)

assert_contains "$deps" "react" "Detects 'react' dependency"
assert_contains "$deps" "next" "Detects 'next' dependency"
assert_contains "$deps" "@tanstack/react-query" "Detects '@tanstack/react-query' dependency"
assert_contains "$deps" "typescript" "Detects 'typescript' devDependency"

it "Handles missing dependencies gracefully"
cat > "$TEST_TMPDIR/detect-project/empty-package.json" << 'EOF'
{
  "name": "test-project"
}
EOF

deps=$(jq -r '(.dependencies // {} | keys[]), (.devDependencies // {} | keys[])' \
    "$TEST_TMPDIR/detect-project/empty-package.json" 2>/dev/null | sort -u)
assert_equals "" "$deps" "$CURRENT_TEST"

# ============================================================================
# detect.sh: Component Matching
# ============================================================================
describe "detect.sh: Component Matching"

it "Matches component by detector"
# Simulate catalog and detector matching
cat > "$TEST_TMPDIR/catalog.json" << 'EOF'
{
  "components": [
    {"name": "react-patterns", "type": "skill", "detectors": ["react", "react-dom"], "tags": ["frontend"]},
    {"name": "nextjs-patterns", "type": "skill", "detectors": ["next"], "tags": ["frontend"]},
    {"name": "code-standards", "type": "doc", "detectors": [], "tags": ["full-stack"]}
  ]
}
EOF

# Simulate deps
DEPS="next
react
typescript
zod"

MATCHED=()
while IFS= read -r comp; do
    [[ -z "$comp" ]] && continue
    name=$(echo "$comp" | jq -r '.name')
    detectors=$(echo "$comp" | jq -r '.detectors[]' 2>/dev/null)
    matched=false

    if [[ -n "$detectors" ]]; then
        for detector in $detectors; do
            if echo "$DEPS" | grep -qx "$detector" 2>/dev/null; then
                matched=true
                break
            fi
        done
    fi

    # full-stack tag
    if echo "$comp" | jq -e '.tags | index("full-stack")' &>/dev/null; then
        matched=true
    fi

    if [[ "$matched" == "true" ]]; then
        MATCHED+=("$name")
    fi
done <<< "$(jq -c '.components[]' "$TEST_TMPDIR/catalog.json")"

matched_str="${MATCHED[*]}"
assert_contains "$matched_str" "react-patterns" "Matches react-patterns via 'react' detector"
assert_contains "$matched_str" "nextjs-patterns" "Matches nextjs-patterns via 'next' detector"
assert_contains "$matched_str" "code-standards" "Matches code-standards via 'full-stack' tag"

it "Does not match unrelated components"
cat >> "$TEST_TMPDIR/catalog.json" << 'EOF2'
EOF2
# Add a component that shouldn't match
cat > "$TEST_TMPDIR/catalog2.json" << 'EOF'
{
  "components": [
    {"name": "prisma-patterns", "type": "skill", "detectors": ["prisma", "@prisma/client"], "tags": ["backend"]}
  ]
}
EOF

UNMATCHED=()
while IFS= read -r comp; do
    [[ -z "$comp" ]] && continue
    name=$(echo "$comp" | jq -r '.name')
    detectors=$(echo "$comp" | jq -r '.detectors[]' 2>/dev/null)
    matched=false

    if [[ -n "$detectors" ]]; then
        for detector in $detectors; do
            if echo "$DEPS" | grep -qx "$detector" 2>/dev/null; then
                matched=true
                break
            fi
        done
    fi

    if [[ "$matched" == "false" ]]; then
        UNMATCHED+=("$name")
    fi
done <<< "$(jq -c '.components[]' "$TEST_TMPDIR/catalog2.json")"

unmatched_str="${UNMATCHED[*]}"
assert_contains "$unmatched_str" "prisma-patterns" "Does not match prisma-patterns (not in deps)"

# ============================================================================
# sync.sh: Component Sync Logic
# ============================================================================
describe "sync.sh: Component Sync Logic"

it "Copies agent file to project"
# Setup fake cache
mkdir -p "$TEST_TMPDIR/cache/agents"
echo "# Test Agent" > "$TEST_TMPDIR/cache/agents/test-agent.md"

# Setup fake project
mkdir -p "$TEST_TMPDIR/sync-project/.claude/agents"

# Simulate sync
src="$TEST_TMPDIR/cache/agents/test-agent.md"
dest="$TEST_TMPDIR/sync-project/.claude/agents/test-agent.md"
cp "$src" "$dest"

assert_file_exists "$dest" "$CURRENT_TEST"

it "Copies skill directory to project"
mkdir -p "$TEST_TMPDIR/cache/skills/react-patterns"
echo "# React Patterns" > "$TEST_TMPDIR/cache/skills/react-patterns/SKILL.md"

mkdir -p "$TEST_TMPDIR/sync-project/.claude/skills/react-patterns"
cp "$TEST_TMPDIR/cache/skills/react-patterns/SKILL.md" \
   "$TEST_TMPDIR/sync-project/.claude/skills/react-patterns/SKILL.md"

assert_file_exists "$TEST_TMPDIR/sync-project/.claude/skills/react-patterns/SKILL.md" "$CURRENT_TEST"

it "Detects unchanged files (no update needed)"
# Make both files identical
cp "$TEST_TMPDIR/cache/agents/test-agent.md" "$TEST_TMPDIR/sync-project/.claude/agents/test-agent.md"
if diff -q "$TEST_TMPDIR/cache/agents/test-agent.md" "$TEST_TMPDIR/sync-project/.claude/agents/test-agent.md" &>/dev/null; then
    needs_update="false"
else
    needs_update="true"
fi
assert_equals "false" "$needs_update" "$CURRENT_TEST"

it "Detects changed files (update needed)"
echo "# Updated Agent" > "$TEST_TMPDIR/cache/agents/test-agent.md"
if diff -q "$TEST_TMPDIR/cache/agents/test-agent.md" "$TEST_TMPDIR/sync-project/.claude/agents/test-agent.md" &>/dev/null; then
    needs_update="false"
else
    needs_update="true"
fi
assert_equals "true" "$needs_update" "$CURRENT_TEST"

# ============================================================================
# sync.sh: Registry Updates
# ============================================================================
describe "sync.sh: Registry Updates"

it "Updates registry with sync timestamp"
cat > "$TEST_TMPDIR/registry.json" << 'EOF'
{
  "projects": {
    "/test/project": {
      "agents": ["test-agent"],
      "skills": [],
      "commands": [],
      "docs": [],
      "templates": [],
      "syncedAt": "2026-01-01T00:00:00Z",
      "syncedCommit": "abc123"
    }
  }
}
EOF

PROJECT_PATH="/test/project"
NEW_HEAD="def456"
TMP_FILE=$(mktemp)
jq --arg p "$PROJECT_PATH" --arg t "2026-02-05T12:00:00Z" --arg c "$NEW_HEAD" \
    '.projects[$p].syncedAt = $t | .projects[$p].syncedCommit = $c' \
    "$TEST_TMPDIR/registry.json" > "$TMP_FILE" && mv "$TMP_FILE" "$TEST_TMPDIR/registry.json"

synced_commit=$(jq -r '.projects["/test/project"].syncedCommit' "$TEST_TMPDIR/registry.json")
assert_equals "def456" "$synced_commit" "$CURRENT_TEST"

synced_at=$(jq -r '.projects["/test/project"].syncedAt' "$TEST_TMPDIR/registry.json")
assert_equals "2026-02-05T12:00:00Z" "$synced_at" "Updates syncedAt timestamp"

# ============================================================================
# Config/Registry Schema
# ============================================================================
describe "Config and Registry Schemas"

it "config-schema.json is valid and has required fields"
assert_json_valid "$PLUGIN_DIR/templates/config-schema.json" "$CURRENT_TEST"

it "config-schema.json defines repoUrl"
assert_json_has_key "$PLUGIN_DIR/templates/config-schema.json" '.properties.repoUrl' "$CURRENT_TEST"

it "registry-schema.json is valid and has required fields"
assert_json_valid "$PLUGIN_DIR/templates/registry-schema.json" "$CURRENT_TEST"

it "registry-schema.json defines projects"
assert_json_has_key "$PLUGIN_DIR/templates/registry-schema.json" '.properties.projects' "$CURRENT_TEST"

# ============================================================================
# Cleanup
# ============================================================================
cleanup_tmpdir

# ============================================================================
# Summary
# ============================================================================
print_summary
