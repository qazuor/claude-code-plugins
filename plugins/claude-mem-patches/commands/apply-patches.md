---
name: apply-patches
description: Apply custom patches to the installed claude-mem plugin (worker auto-restart, enhanced watchdog, crontab)
allowed-tools:
  - Bash
  - Read
---

# Apply Claude-Mem Patches

Apply all custom patches to the installed claude-mem plugin.

## What this does

1. **Worker auto-restart patch**: Modifies `worker-utils.ts` so the worker automatically restarts when it fails to respond, instead of blocking Claude Code and asking for manual intervention.
2. **Enhanced watchdog**: Installs the improved watchdog with queue stall detection, restart cooldown, and better logging.
3. **Crontab setup**: Configures the watchdog to run every 10 minutes.
4. **Rebuild**: Rebuilds the claude-mem plugin to compile the patched source.
5. **Worker restart**: Restarts the worker with the new code.

## Instructions

Run the apply script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/apply-patches.sh"
```

For a dry run (see what would change without modifying anything):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/apply-patches.sh" --dry-run
```

Options:
- `--dry-run`: Show what would be done without making changes
- `--skip-rebuild`: Skip the plugin rebuild step
- `--skip-cron`: Skip crontab setup for watchdog

## When to use

Run this command after:
- Fresh installation of claude-mem on a new machine
- Updating claude-mem to a new version (patches may need to be re-applied)

## Verify

After applying, verify the worker is running:

```bash
cd ~/.claude/plugins/marketplaces/thedotmack && npm run worker:status
```
