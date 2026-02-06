# Plugin Format Specification

This document describes the canonical format for Claude Code plugins in this marketplace.
Formats are aligned with the official [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code).

## Table of Contents

- [Directory Structure](#directory-structure)
- [Plugin Manifest](#plugin-manifest)
- [Marketplace Manifest](#marketplace-manifest)
- [Agent Format](#agent-format)
- [Command Format](#command-format)
- [Skill Format](#skill-format)
- [Hooks Format](#hooks-format)
- [MCP Server Format](#mcp-server-format)
- [Naming Conventions](#naming-conventions)
- [Variables Reference](#variables-reference)

---

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

**Notes:**
- Only `.claude-plugin/plugin.json` is required
- All other directories are optional based on plugin needs
- Scripts must be executable (`chmod +x`)

---

## Plugin Manifest

**Location:** `.claude-plugin/plugin.json`

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

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Must match directory name. Lowercase, hyphens allowed |
| `version` | Yes | Semantic version (e.g., `1.0.0`) |
| `description` | Yes | One-line description of what the plugin does |
| `author` | No | Author information |
| `repository` | No | URL to source repository |
| `license` | No | License identifier (e.g., `MIT`) |
| `keywords` | No | Search keywords for discovery |

---

## Marketplace Manifest

**Location:** `.claude-plugin/marketplace.json` (repository root)

This file enables plugin discovery when adding the repository as a marketplace.

```json
{
  "name": "marketplace-name",
  "owner": {
    "name": "Owner Name",
    "url": "https://github.com/owner"
  },
  "metadata": {
    "description": "Collection description",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "description": "What this plugin does",
      "source": "./plugins/plugin-name"
    }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Marketplace identifier |
| `owner` | No | Owner information |
| `metadata.description` | No | Marketplace description |
| `metadata.version` | No | Marketplace version |
| `plugins` | Yes | Array of available plugins |
| `plugins[].name` | Yes | Plugin name (must match plugin's manifest) |
| `plugins[].description` | Yes | Brief description |
| `plugins[].source` | Yes | Relative path to plugin directory |

---

## Agent Format

Agents (subagents) are specialized AI assistants that handle specific types of tasks.
Each agent runs in its own context with a custom system message.

Based on the official [sub-agents documentation](https://docs.anthropic.com/en/docs/claude-code/sub-agents).

**Location:** `agents/<name>.md`

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier (lowercase, hyphens) |
| `description` | Yes | When Claude should delegate to this agent |
| `tools` | No | Comma-separated tools. Inherits all if omitted |
| `disallowedTools` | No | Tools to deny from inherited set |
| `model` | No | `sonnet` (default), `opus`, `haiku`, or `inherit` |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `skills` | No | Skills to preload at startup |
| `hooks` | No | Lifecycle hooks scoped to this agent |

### Example

```markdown
---
name: tech-lead
description: Delegates architectural decisions, code reviews, and technical planning
tools: Read, Write, Edit, Glob, Grep, Bash, Task
model: sonnet
---

You are the **Tech Lead** for the current project. Your primary
responsibility is to make architectural decisions and ensure code quality.

## Core Responsibilities

### 1. Architecture
- Design system architecture
- Define patterns and conventions
- Review technical decisions

### 2. Code Quality
- Review pull requests
- Enforce coding standards
- Identify technical debt

## Working Context

### Key Documents
- **Input**: Requirements, code changes, technical questions
- **Output**: Architectural decisions, code reviews, technical guidance
```

---

## Command Format

Commands are slash commands (e.g., `/my-command`) defined as markdown files.

**Location:** `commands/<name>.md`

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Command name (without `/`). Defaults to filename |
| `description` | Recommended | What the command does. Used for auto-discovery |
| `disable-model-invocation` | No | `true` to prevent auto-loading. Default: `false` |
| `user-invocable` | No | `false` to hide from `/` menu. Default: `true` |
| `allowed-tools` | No | Tools allowed without permission when active |
| `model` | No | Model to use when command is active |
| `context` | No | `fork` to run in subagent context |
| `agent` | No | Subagent type when `context: fork` |

### Example

```markdown
---
name: quality-check
description: Run comprehensive quality checks on the codebase
allowed-tools: Bash, Read, Glob, Grep
---

# /quality-check

## Purpose

Run linting, type checking, and tests to verify code quality.

## Process

1. Run linter (`pnpm lint`)
2. Run type checker (`pnpm typecheck`)
3. Run tests (`pnpm test`)
4. Report any failures with file locations

## Options

- `--fix`: Auto-fix linting issues
- `--coverage`: Include test coverage report

## Output Format

```text
Quality Check Results
---------------------
Lint: PASS/FAIL (X issues)
Types: PASS/FAIL (X errors)
Tests: PASS/FAIL (X/Y passed)
```

---

## Skill Format

Skills extend what Claude can do with reusable knowledge patterns.

Based on the official [skills documentation](https://docs.anthropic.com/en/docs/claude-code/skills).

**Location:** `skills/<name>/SKILL.md` (note: uppercase `SKILL.md`)

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name. Defaults to directory name |
| `description` | Recommended | What the skill does. Used for auto-discovery |
| `argument-hint` | No | Hint for autocompletion (e.g., `[issue-number]`) |
| `disable-model-invocation` | No | `true` to prevent auto-loading |
| `user-invocable` | No | `false` to hide from `/` menu |
| `allowed-tools` | No | Tools allowed without permission when active |
| `model` | No | Model to use when skill is active |
| `context` | No | `fork` to run in subagent context |
| `agent` | No | Subagent type when `context: fork` |
| `hooks` | No | Hooks scoped to this skill's lifecycle |

### Example

```markdown
---
name: react-patterns
description: Modern React patterns and best practices. Use when working with React components.
---

# React Patterns

## Purpose

Provide patterns and best practices for React development.

## Patterns

### 1. Component Composition

Use composition over inheritance:

```tsx
interface CardProps {
  children: React.ReactNode;
  header?: React.ReactNode;
}

export function Card({ children, header }: CardProps) {
  return (
    <div className="card">
      {header && <div className="card-header">{header}</div>}
      <div className="card-body">{children}</div>
    </div>
  );
}
```

### 2. Custom Hooks

Extract reusable logic into hooks:

```tsx
function useLocalStorage<T>(key: string, initialValue: T) {
  const [value, setValue] = useState<T>(() => {
    const stored = localStorage.getItem(key);
    return stored ? JSON.parse(stored) : initialValue;
  });

  useEffect(() => {
    localStorage.setItem(key, JSON.stringify(value));
  }, [key, value]);

  return [value, setValue] as const;
}
```

## Best Practices

- Prefer functional components with hooks
- Keep components small and focused
- Use TypeScript for type safety
- Memoize expensive computations
```

### Supporting Files

Skills can include additional files in their directory:

```
my-skill/
├── SKILL.md           # Main instructions (required)
├── template.md        # Template for Claude to fill in
├── examples/
│   └── sample.md      # Example output
└── scripts/
    └── validate.sh    # Script Claude can execute
```

---

## Hooks Format

Hooks execute shell commands or prompts in response to Claude Code events.

Based on the official [hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks).

**Location:** `hooks/hooks.json`

### Structure

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

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `description` | Recommended | What these hooks do |
| `hooks` | Yes | Object keyed by event name |
| `hooks[event]` | Yes | Array of matcher groups |
| `matcher` | No | Tool pattern (for `PreToolUse`, `PostToolUse`, `PermissionRequest`) |
| `hooks[].type` | Yes | `"command"` or `"prompt"` |
| `hooks[].command` | Yes* | Shell command to execute (if type is command) |
| `hooks[].prompt` | Yes* | Prompt to inject (if type is prompt) |
| `hooks[].timeout` | No | Timeout in seconds |

### Available Events

| Event | Matcher | Description |
|-------|---------|-------------|
| `SessionStart` | No | Session begins |
| `UserPromptSubmit` | No | User submits a prompt |
| `PreToolUse` | Yes | Before a tool executes |
| `PostToolUse` | Yes | After a tool executes |
| `PostToolUseFailure` | Yes | After a tool fails |
| `PermissionRequest` | Yes | Permission requested |
| `SubagentStart` | No | Subagent starts |
| `SubagentStop` | No | Subagent completes |
| `Stop` | No | Main session ends |
| `PreCompact` | No | Before context compaction |
| `Notification` | No | Notification triggered |
| `SessionEnd` | No | Session ends completely |
| `Setup` | No | Plugin setup |

### Example

```json
{
  "description": "Session lifecycle hooks for task management",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/session-resume.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Before compacting, create a diary entry with /diary"
          }
        ]
      }
    ]
  }
}
```

---

## MCP Server Format

MCP (Model Context Protocol) server definitions for external tool integrations.

**Location:** `.mcp.json`

### Structure

```json
{
  "version": "1.0.0",
  "description": "Description of these MCP servers",
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

### Server Types

**Command-based (local process):**

```json
{
  "server-name": {
    "command": "npx",
    "args": ["-y", "@scope/mcp-server"],
    "env": {
      "API_KEY": "${API_KEY:-}"
    }
  }
}
```

**HTTP-based (remote endpoint):**

```json
{
  "server-name": {
    "type": "http",
    "url": "https://mcp.example.com/mcp"
  }
}
```

### Environment Variables

Use safe defaults to avoid errors when variables are missing:

```json
{
  "env": {
    "REQUIRED_KEY": "${API_KEY}",
    "OPTIONAL_KEY": "${API_KEY:-}",
    "WITH_DEFAULT": "${API_KEY:-default_value}"
  }
}
```

---

## Naming Conventions

| Component | Convention | Example |
|-----------|------------|---------|
| Plugin directory | kebab-case | `my-plugin/` |
| Agent file | kebab-case.md | `tech-lead.md` |
| Command file | kebab-case.md | `quality-check.md` |
| Skill directory | kebab-case | `react-patterns/` |
| Skill file | SKILL.md (uppercase) | `SKILL.md` |
| Hook script | kebab-case.sh | `on-notification.sh` |
| Template file | kebab-case.ext | `brand-config.json` |
| Hook event | PascalCase | `SessionStart` |

---

## Variables Reference

Available in hook commands and scripts:

| Variable | Description |
|----------|-------------|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the plugin directory |
| `${CLAUDE_PROJECT_DIR}` | Absolute path to the project root |

**Example usage in hooks.json:**

```json
{
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/my-script.sh"
}
```

**Example usage in scripts:**

```bash
#!/bin/bash
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
```
