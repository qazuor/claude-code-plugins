---
name: sync-permissions
description: Manually synchronize permissions between base configuration and current project
allowed-tools: Bash, Read, Write
---

# Sync Permissions

Manually synchronize permissions between base configuration and current project.

## Usage

```
/sync-permissions [--all] [--dry-run]
```

## Options

- `--all`: Sync all projects in ~/projects
- `--dry-run`: Show what would be synced without making changes

## What it does

1. **Auto-learn**: Detects permissions in current project that aren't in base and adds them
2. **Merge**: Applies base permissions to current project
3. **Report**: Shows what was synced

## Examples

```bash
# Sync current project
/sync-permissions

# Sync all projects
/sync-permissions --all

# Preview changes without applying
/sync-permissions --dry-run
```

---

$ARGUMENTS

Run the sync script:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/projects/TOOLS/claude-code-plugins/plugins/permission-sync}"
"$PLUGIN_ROOT/scripts/permissions-sync-all.sh" $ARGUMENTS
```
