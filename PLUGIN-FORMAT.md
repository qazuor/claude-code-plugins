# Plugin Format Specification

This document describes the canonical format for Claude Code plugins in this marketplace.

## Directory Structure

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest (required)
├── agents/                   # Agent definitions (.md files)
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

Agents are markdown files with YAML frontmatter. They define AI personas with specific domain expertise.

```markdown
---
name: agent-name
description: Brief description of what this agent does
tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
---

# Agent Name

## Role & Responsibility

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

```markdown
---
name: command-name
description: Brief description
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

Skills use `SKILL.md` (uppercase) inside a named subdirectory. They define reusable knowledge patterns.

```markdown
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

## Hooks Format

`hooks/hooks.json`:

```json
{
  "hooks": [
    {
      "event": "Notification|Stop|SubagentStop|SessionStart",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/script-name.sh",
      "timeout": 10000
    }
  ]
}
```

**Available events:** `Notification`, `Stop`, `SubagentStop`, `SessionStart`

**Variables:**
- `${CLAUDE_PLUGIN_ROOT}` — Absolute path to the plugin directory

## MCP Server Format

`.mcp.json`:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@scope/mcp-server-name"],
      "env": {
        "API_KEY": "${API_KEY}"
      }
    }
  }
}
```

## Naming Conventions

| Component | Convention | Example |
|-----------|-----------|---------|
| Agent file | kebab-case.md | `tech-lead.md` |
| Command file | kebab-case.md | `quality-check.md` |
| Skill directory | kebab-case/ | `tdd-methodology/` |
| Skill file | SKILL.md (uppercase) | `SKILL.md` |
| Hook script | kebab-case.sh | `on-notification.sh` |
| Plugin directory | kebab-case/ | `mcp-servers/` |
