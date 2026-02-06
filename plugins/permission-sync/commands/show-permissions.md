---
name: show-permissions
description: Display the current state of permissions comparing base vs project
allowed-tools: Bash, Read
---

# Show Permissions

Display the current state of permissions: base vs project.

## Usage

```
/show-permissions [--diff] [--base] [--project]
```

## Options

- `--diff`: Show only differences between base and project
- `--base`: Show only base permissions
- `--project`: Show only project permissions

## What it shows

- Total permissions in base
- Total permissions in project
- Permissions in project not in base (will be auto-learned)
- Permissions in base not in project (will be merged)

---

## Implementation Rules

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Always check existence before reading: `[ -f "$FILE" ] && ...`
- **Errors**: Suppress with `2>/dev/null` or `|| true` when files might not exist.

---

$ARGUMENTS

Show permission status:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/projects/TOOLS/claude-code-plugins/plugins/permission-sync}"
BASE_PERMS="$PLUGIN_ROOT/templates/base-permissions.json"
PROJECT_SETTINGS=".claude/settings.local.json"

echo "=== PERMISSIONS STATUS ==="
echo ""

if [[ -f "$BASE_PERMS" ]]; then
    base_allow=$(jq '.permissions.allow | length' "$BASE_PERMS")
    base_deny=$(jq '.permissions.deny | length' "$BASE_PERMS")
    echo "Base permissions:"
    echo "  Allow: $base_allow"
    echo "  Deny:  $base_deny"
else
    echo "Base permissions file not found!"
fi

echo ""

if [[ -f "$PROJECT_SETTINGS" ]]; then
    proj_allow=$(jq '.permissions.allow // [] | length' "$PROJECT_SETTINGS")
    proj_deny=$(jq '.permissions.deny // [] | length' "$PROJECT_SETTINGS")
    echo "Project permissions:"
    echo "  Allow: $proj_allow"
    echo "  Deny:  $proj_deny"

    echo ""
    echo "=== DIFF ==="

    # Permissions in project not in base
    echo ""
    echo "New in project (will be learned):"
    jq -r '.permissions.allow // [] | .[]' "$PROJECT_SETTINGS" | while read perm; do
        if ! jq -e --arg p "$perm" '.permissions.allow | index($p)' "$BASE_PERMS" >/dev/null 2>&1; then
            echo "  + $perm"
        fi
    done

    # Permissions in base not in project
    echo ""
    echo "Missing from project (will be merged):"
    jq -r '.permissions.allow // [] | .[]' "$BASE_PERMS" | while read perm; do
        if ! jq -e --arg p "$perm" '.permissions.allow // [] | index($p)' "$PROJECT_SETTINGS" >/dev/null 2>&1; then
            echo "  - $perm"
        fi
    done | head -20
    echo "  ... (use --base to see all)"
else
    echo "No project settings found at $PROJECT_SETTINGS"
fi
```
