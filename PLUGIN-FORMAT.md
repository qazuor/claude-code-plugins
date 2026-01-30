# Plugin Format Specification

This document describes the canonical format for Claude Code plugins in this marketplace.
Formats are aligned with the official [Claude Code documentation](https://code.claude.com/docs).

## Directory Structure

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest (required)
├── agents/                   # Subagent definitions (.md files)
├── commands/                 # Command definitions (.md files)
├── skills/                   # Skill definitions (subdirs with SKILL.md)
├── docs/                     # Documentation and standards (.md files)
├── templates/                # Templates (.md, .json, .yml files)
├── hooks/
│   └── hooks.json           # Hook event definitions
├── scripts/                  # Shell scripts for hooks
└── .mcp.json                # MCP server definitions (optional)
```

## Plugin Manifest

`.claude-plugin/plugin.json`:

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Brief description of the plugin",
  "author": {
    "name": "Author Name",
    "url": "https://github.com/author"
  },
  "repository": "https://github.com/author/repo",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"]
}
```

## Agent Format

Agents (subagents) are markdown files with YAML frontmatter. They define specialized AI assistants
that handle specific types of tasks. Each agent runs in its own context window with a custom system
message, specific tool access, and independent permissions.

Based on the official [sub-agents documentation](https://code.claude.com/docs/sub-agents).

### Supported Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier using lowercase letters and hyphens |
| `description` | Yes | When Claude should delegate to this subagent |
| `tools` | No | Tools the subagent can use (comma-separated). Inherits all if omitted |
| `disallowedTools` | No | Tools to deny, removed from the inherited or specified list |
| `model` | No | Model to use: `sonnet`, `opus`, `haiku`, or `inherit`. Default: `sonnet` |
| `permissionMode` | No | Permission mode: `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `skills` | No | Skills to preload into the subagent's context at startup |
| `hooks` | No | Lifecycle hooks scoped to this subagent |

### Example

```markdown
---
name: agent-name
description: Brief description of what this agent does and when Claude should delegate to it
tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
---

You are the **Agent Name** for the current project. Your primary
responsibility is to [describe main purpose].

## Core Responsibilities

### 1. [Area]
- Responsibility 1
- Responsibility 2

## Working Context

### Key Documents You Work With
- **Input**: [what this agent receives]
- **Output**: [what this agent produces]
```

**Location:** `agents/<name>.md`

## Command Format

Commands are markdown files that define slash commands (e.g., `/quality-check`).
Commands follow the same format as [skills](https://code.claude.com/docs/skills) since
custom slash commands have been merged into the skills system.

### Supported Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Command name (without `/`). Defaults to directory or file name |
| `description` | Recommended | What the command does. Claude uses this to decide when to apply it |
| `disable-model-invocation` | No | Set to `true` to prevent Claude from auto-loading. Default: `false` |
| `user-invocable` | No | Set to `false` to hide from `/` menu. Default: `true` |
| `allowed-tools` | No | Tools Claude can use without permission when this command is active |
| `model` | No | Model to use when this command is active |
| `context` | No | Set to `fork` to run in a subagent context |
| `agent` | No | Subagent type to use when `context: fork` is set |

### Example

```markdown
---
name: command-name
description: Brief description of what this command does
---

# /command-name

## Purpose
What this command does.

## Process
1. Step 1
2. Step 2

## Options
- `--option`: Description

## Output Format
Expected output structure.
```

**Location:** `commands/<name>.md`

## Skill Format

Skills extend what Claude can do. They use `SKILL.md` (uppercase) inside a named subdirectory
and define reusable knowledge patterns.

Based on the official [skills documentation](https://code.claude.com/docs/skills).

### Supported Frontmatter Fields

All fields are optional. Only `description` is recommended so Claude knows when to use the skill.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name. Defaults to directory name. Lowercase, numbers, hyphens (max 64 chars) |
| `description` | Recommended | What the skill does and when to use it. Claude uses this to decide when to apply it |
| `argument-hint` | No | Hint shown during autocompletion (e.g., `[issue-number]`) |
| `disable-model-invocation` | No | Set to `true` to prevent Claude from auto-loading. Default: `false` |
| `user-invocable` | No | Set to `false` to hide from `/` menu. Default: `true` |
| `allowed-tools` | No | Tools Claude can use without permission when this skill is active |
| `model` | No | Model to use when this skill is active |
| `context` | No | Set to `fork` to run in a subagent context |
| `agent` | No | Subagent type to use when `context: fork` is set |
| `hooks` | No | Hooks scoped to this skill's lifecycle |

### Example

```markdown
---
name: skill-name
description: What patterns/knowledge this skill provides. Use when [context for automatic loading].
---

# Skill Name

## Purpose
What patterns/knowledge this skill provides.

## Patterns

### Pattern 1: [Name]
Description and code examples.

### Pattern 2: [Name]
Description and code examples.

## Best Practices
- Practice 1
- Practice 2
```

**Location:** `skills/<name>/SKILL.md`

Skills can include supporting files in their directory:

```
my-skill/
├── SKILL.md           # Main instructions (required)
├── template.md        # Template for Claude to fill in
├── examples/
│   └── sample.md      # Example output showing expected format
└── scripts/
    └── validate.sh    # Script Claude can execute
```

## Hooks Format

Based on the official [hooks documentation](https://code.claude.com/docs/en/hooks).

`hooks/hooks.json`:

```json
{
  "description": "Description of what these hooks do",
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolPattern",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/script-name.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Structure:**
- `hooks` is an object keyed by event name
- Each event contains an array of matcher groups
- Each matcher group has an optional `matcher` (for `PreToolUse`, `PostToolUse`, `PermissionRequest`) and a `hooks` array
- Each hook has `type` (`"command"` or `"prompt"`), `command`/`prompt`, and optional `timeout` (in seconds)
- For events without matchers (`Notification`, `Stop`, `SessionStart`, etc.), omit the `matcher` field

**Available events:** `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`,
`PostToolUse`, `PostToolUseFailure`, `SubagentStart`, `SubagentStop`, `Stop`, `PreCompact`,
`Notification`, `Setup`, `SessionEnd`

**Variables:**
- `${CLAUDE_PLUGIN_ROOT}` — Absolute path to the plugin directory
- `${CLAUDE_PROJECT_DIR}` — Absolute path to the project root directory

## MCP Server Format

`.mcp.json`:

```json
{
  "$schema": "./mcp-schema.json",
  "version": "1.0.0",
  "description": "Description of the MCP server configuration",
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@scope/mcp-server-name"],
      "env": {
        "API_KEY": "${API_KEY:-}"
      }
    }
  }
}
```

Environment variables should use the `${VAR:-}` syntax (with empty default) or
`${VAR:-default_value}` to provide safe fallback values.

## Naming Conventions

| Component | Convention | Example |
|-----------|-----------|---------|
| Agent file | kebab-case.md | `tech-lead.md` |
| Command file | kebab-case.md | `quality-check.md` |
| Skill directory | kebab-case/ | `tdd-methodology/` |
| Skill file | SKILL.md (uppercase) | `SKILL.md` |
| Hook script | kebab-case.sh | `on-notification.sh` |
| Plugin directory | kebab-case/ | `mcp-servers/` |
