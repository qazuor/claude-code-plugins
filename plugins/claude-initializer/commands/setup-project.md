---
name: setup-project
description: Orchestrate full project setup by running init, knowledge sync, permissions, and guardrails
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill
---

# /setup-project

## Purpose

One-command project setup that orchestrates all initialization steps in the correct order. Validates claude-mem infrastructure first, then runs init-project, knowledge-sync, permission-sync, and guardrails initialization so a project is fully configured in a single pass.

## Process

You are the setup orchestrator for the claude-initializer plugin. Your job is to validate prerequisites, run all setup steps in sequence, skipping steps that are already done, and presenting a final summary.

## Step 1: Claude-Mem Validation (BLOCKING)

This step runs **before anything else** and is **blocking**.. if it fails, the setup stops.

### 1a. Check if claude-mem is installed

Check if the directory `~/.claude/plugins/marketplaces/thedotmack` exists and contains `src/shared/worker-utils.ts`.

If claude-mem is **NOT installed**, stop immediately and show:

```
SETUP ABORTED
=============

claude-mem is not installed. It is required before running project setup.

To install claude-mem:
  1. Visit https://github.com/thedotmack/claude-mem
  2. Follow the installation instructions
  3. Restart Claude Code
  4. Run /setup-project again
```

Do NOT continue with any further steps.

### 1b. Check if claude-mem-patches plugin is available

Check if the claude-mem-patches plugin exists by looking for the apply script. Search for it in these locations (in order):
1. The plugin root via `CLAUDE_PLUGIN_ROOT` parent directory: look for a sibling `claude-mem-patches/scripts/apply-patches.sh`
2. Common plugin locations: `~/projects/TOOLS/claude-code-plugins/plugins/claude-mem-patches/scripts/apply-patches.sh`

If claude-mem-patches is **NOT found**, stop immediately and show:

```
SETUP ABORTED
=============

claude-mem-patches plugin is not installed. It is required before running project setup.

To install:
  1. Ensure claude-code-plugins repository is cloned
  2. The claude-mem-patches plugin should be at: plugins/claude-mem-patches/
  3. Run /setup-project again
```

Do NOT continue with any further steps.

### 1c. Apply claude-mem patches

If both are present, check if patches are already applied by looking for `"Auto-restart: try to recover instead of requiring manual intervention"` in `~/.claude/plugins/marketplaces/thedotmack/src/shared/worker-utils.ts`.

If patches are already applied:

```
Step 0/6: Claude-mem patches already applied. Skipping.
```

If patches need to be applied, run the apply script:

```bash
bash <path-to-claude-mem-patches>/scripts/apply-patches.sh
```

Show the output and confirm success:

```
Step 0/6: Claude-mem patches applied successfully.
```

If the apply script fails, show the error but continue with the rest of the setup (patches are important but not blocking for project init).

## Step 2: Check Prerequisites

Check if `.claude/` directory already exists:

- If `.claude/` exists AND `.claude/CLAUDE.md` exists: project is already initialized
- If `.claude/` does not exist: project needs initialization

```
PROJECT SETUP
=============

Project: <directory name>
Location: <project root>

Checking prerequisites...
  .claude/ directory: [exists/missing]
  CLAUDE.md: [exists/missing]
  tasks/index.json: [exists/missing]
  guardrails.md: [exists/missing]
  settings.local.json: [exists/missing]
```

## Step 3: Init Project

If `.claude/` does not exist or `CLAUDE.md` is missing:

```
Step 1/6: Initializing project...
```

Execute `/init-project` to create the base configuration.

If already initialized:

```
Step 1/6: Project already initialized. Skipping.
```

## Step 4: Knowledge Sync

```
Step 2/6: Syncing knowledge components...
```

Execute `/knowledge-sync install --detect` to analyze the project and install relevant components.

If knowledge-sync is not available (plugin not installed):

```
Step 2/6: knowledge-sync plugin not available. Skipping.
  Install the knowledge-sync plugin for automatic component detection.
```

## Step 5: Permissions Sync

```
Step 3/6: Syncing permissions...
```

Execute `/sync-permissions` to apply base permissions to the project.

If permission-sync is not available:

```
Step 3/6: permission-sync plugin not available. Skipping.
  Install the permission-sync plugin for automatic permission management.
```

## Step 6: Guardrails Init

```
Step 4/6: Initializing guardrails...
```

Check if `.claude/guardrails.md` already exists:

- If it exists: skip, show current guardrails count
- If it does not exist: copy the guardrails template

The guardrails template is located at the task-master plugin's templates directory. Read the template from `guardrails-template.md` in the task-master plugin and write it to `.claude/guardrails.md` in the project.

```
Guardrails initialized with 4 seed signs.
Review and customize at .claude/guardrails.md
```

If guardrails already exist:

```
Step 4/6: Guardrails already configured (N signs). Skipping.
```

If task-master plugin is not available:

```
Step 4/6: task-master plugin not available. Skipping guardrails.
  Install the task-master plugin for guardrails and task management.
```

## Step 7: Summary

```
SETUP COMPLETE
==============

  [x] Claude-mem patches applied
  [x] Project initialized (.claude/ directory, CLAUDE.md)
  [x] Knowledge components installed (N components)
  [x] Permissions synced (N rules)
  [x] Guardrails initialized (4 signs)
  [ ] Tasks - no specs yet

Next steps:
  1. Review .claude/CLAUDE.md and customize for your project
  2. Review .claude/guardrails.md and add project-specific constraints
  3. Use /spec to create your first specification
  4. Use /auto-loop to start autonomous task processing
```

Show which steps were executed vs skipped:

```
Steps executed: N/6
Steps skipped: N/6 (already configured)
```

## Notes

- This command is idempotent: running it multiple times will skip already-completed steps
- Claude-mem and claude-mem-patches are **blocking prerequisites**.. setup will not continue without them
- Each subsequent step is independent: if one fails, others can still proceed
- The command depends on other plugins being installed for full functionality
- Guardrails template comes from the task-master plugin
- If running for the first time, all 6 steps will execute
- If running on an already-configured project, most steps will be skipped

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Create with `mkdir -p` and check existence with `[ -d "$DIR" ]`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
