---
name: setup-project
description: Orchestrate full project setup by running init, knowledge sync, permissions, and guardrails
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill
---

# /setup-project

## Purpose

One-command project setup that orchestrates all initialization steps in the correct order. Runs init-project, knowledge-sync, permission-sync, and guardrails initialization so a project is fully configured in a single pass.

## Process

You are the setup orchestrator for the claude-initializer plugin. Your job is to run all setup steps in sequence, skipping steps that are already done, and presenting a final summary.

## Step 1: Check Prerequisites

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

## Step 2: Init Project

If `.claude/` does not exist or `CLAUDE.md` is missing:

```
Step 1/5: Initializing project...
```

Execute `/init-project` to create the base configuration.

If already initialized:

```
Step 1/5: Project already initialized. Skipping.
```

## Step 3: Knowledge Sync

```
Step 2/5: Syncing knowledge components...
```

Execute `/knowledge-sync install --detect` to analyze the project and install relevant components.

If knowledge-sync is not available (plugin not installed):

```
Step 2/5: knowledge-sync plugin not available. Skipping.
  Install the knowledge-sync plugin for automatic component detection.
```

## Step 4: Permissions Sync

```
Step 3/5: Syncing permissions...
```

Execute `/sync-permissions` to apply base permissions to the project.

If permission-sync is not available:

```
Step 3/5: permission-sync plugin not available. Skipping.
  Install the permission-sync plugin for automatic permission management.
```

## Step 5: Guardrails Init

```
Step 4/5: Initializing guardrails...
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
Step 4/5: Guardrails already configured (N signs). Skipping.
```

If task-master plugin is not available:

```
Step 4/5: task-master plugin not available. Skipping guardrails.
  Install the task-master plugin for guardrails and task management.
```

## Step 6: Summary

```
SETUP COMPLETE
==============

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
Steps executed: 3/5
Steps skipped: 2/5 (already configured)
```

## Notes

- This command is idempotent: running it multiple times will skip already-completed steps
- Each step is independent: if one fails, others can still proceed
- The command depends on other plugins being installed for full functionality
- Guardrails template comes from the task-master plugin
- If running for the first time, all 5 steps will execute
- If running on an already-configured project, most steps will be skipped

---

## Implementation Rules (MUST FOLLOW)

- **JSON**: Use ONLY `jq` for JSON processing. NEVER use Python or Node.js.
- **Files**: Check existence before reading: `[ -f "$FILE" ] && jq '.' "$FILE"`
- **Directories**: Create with `mkdir -p` and check existence with `[ -d "$DIR" ]`
- **Errors**: ALWAYS suppress with `2>/dev/null` or `|| true` when files/dirs might not exist.
- **No visible errors**: The user should NEVER see "Exit code" errors in the output.
