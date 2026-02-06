# Claude Code Plugins

[![CI](https://github.com/qazuor/claude-code-plugins/actions/workflows/ci.yml/badge.svg)](https://github.com/qazuor/claude-code-plugins/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Plugins](https://img.shields.io/badge/Plugins-7-green.svg)](#plugins)
[![Version](https://img.shields.io/badge/Version-2.0.0-blue.svg)](CHANGELOG.md)

A curated collection of plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic's official CLI tool). These plugins enhance your Claude Code experience with notifications, task management, permission synchronization, and more.

## Table of Contents

- [Installation](#installation)
- [Plugins Overview](#plugins-overview)
- [Plugin Details](#plugin-details)
  - [notifications](#notifications)
  - [task-master](#task-master)
  - [mcp-servers](#mcp-servers)
  - [permission-sync](#permission-sync)
  - [knowledge-sync](#knowledge-sync)
  - [session-tools](#session-tools)
  - [claude-initializer](#claude-initializer)
- [Knowledge Repository](#knowledge-repository)
- [Usage in Projects](#usage-in-projects)
- [Configuration](#configuration)
- [Contributing](#contributing)

---

## Installation

### Step 1: Add the Marketplace

In Claude Code, run `/plugin` and select **Add marketplace**:

```
qazuor/claude-code-plugins
```

### Step 2: Install Plugins

After adding the marketplace, install the plugins you want:

```
/plugin → Install plugin → Select from qazuor-claude-code-plugins
```

**Recommended minimum:**
- `notifications` - Audio feedback when Claude finishes
- `permission-sync` - Keep permissions consistent across projects
- `task-master` - If you work with specs and tasks

### Step 3: Restart Claude Code

Some plugins register hooks that only activate on session start. Restart Claude Code after installing.

---

## Plugins Overview

| Plugin | Purpose | Auto-runs |
|--------|---------|-----------|
| [notifications](#notifications) | Desktop notifications + audio beeps | On events |
| [task-master](#task-master) | Specs, tasks, progress tracking | SessionStart |
| [mcp-servers](#mcp-servers) | 30 pre-configured MCP servers | Manual |
| [permission-sync](#permission-sync) | Sync permissions across projects | SessionStart |
| [knowledge-sync](#knowledge-sync) | Sync agents/skills from external repo | SessionStart |
| [session-tools](#session-tools) | Diary entries before compaction | PreCompact |
| [claude-initializer](#claude-initializer) | Initialize new projects | Manual |

---

## Plugin Details

### notifications

**Purpose:** Audio and visual feedback when Claude Code needs your attention.

**What it does:**
- Plays a beep (1000Hz) when main session stops
- Plays a lower beep (800Hz) when subagents finish
- Shows desktop notifications with optional TTS (text-to-speech)

**What it doesn't do:**
- No configuration needed
- No commands to run

**Hooks:**
| Event | Action |
|-------|--------|
| `Notification` | Desktop notification + TTS |
| `Stop` | 1000Hz beep (0.2s) |
| `SubagentStop` | 800Hz beep (0.1s) |

**Requirements:** `paplay` (Linux), `afplay` (macOS), or PowerShell (Windows/WSL)

---

### task-master

**Purpose:** Specification-driven development with task decomposition and progress tracking.

**What it does:**
- Creates formal specifications from requirements
- Decomposes specs into atomic, scored tasks with dependencies
- Tracks progress with visual dashboards
- Runs quality gates (lint, typecheck, tests) before completion
- Detects active work on session start

**What it doesn't do:**
- Doesn't replace your project management tool
- Doesn't auto-commit or push code

**Commands:**

| Command | Description |
|---------|-------------|
| `/spec` | Create a specification from requirements |
| `/tasks` | Show task dashboard with progress |
| `/next-task` | Get the next available task |
| `/new-task` | Create a standalone task (no spec needed) |
| `/task-status` | Detailed progress report |
| `/replan` | Modify tasks when requirements change |

**Skills (internal):**

| Skill | Purpose |
|-------|---------|
| `complexity-scorer` | Score tasks 1-10 (ceiling: 4 for atomic) |
| `dependency-grapher` | Validate DAGs, find critical paths |
| `overlap-detector` | Detect duplicate work between specs |
| `quality-gate` | Run lint/typecheck/tests before completion |
| `spec-generator` | Transform plans into formal specs |
| `task-atomizer` | Break features into atomic sub-tasks |
| `task-from-spec` | Generate tasks from spec documents |

**Agents:**

| Agent | Purpose |
|-------|---------|
| `spec-writer` | Generates specs with user stories and BDD criteria |
| `tech-analyzer` | Architecture design and risk assessment |
| `task-planner` | Decomposes specs into implementable tasks |

**Hook:** Shows active work summary on SessionStart

---

### mcp-servers

**Purpose:** Pre-configured MCP (Model Context Protocol) server definitions.

**What it does:**
- Provides 30 ready-to-use MCP server configurations
- Covers databases, browsers, Git, GitHub, Docker, and more
- Just add API keys and enable

**What it doesn't do:**
- Doesn't install the MCP servers (you need npm/uvx)
- Doesn't manage API keys (you provide them)

**Included Servers (30):**

| Category | Servers |
|----------|---------|
| Thinking | `sequential-thinking`, `context7` |
| Search | `perplexity-ask`, `brave-search` |
| Data | `json`, `drizzle`, `shadcn` |
| Filesystem | `filesystem`, `git` |
| GitHub | `github` |
| Browsers | `playwright`, `puppeteer`, `chrome-devtools` |
| Containers | `docker` |
| Databases | `postgres`, `sqlite`, `prisma`, `neon` |
| Cache | `redis-upstash` |
| Dev Tools | `memory`, `@21st-dev/magic`, `figma` |
| Testing | `browserstack` |
| Platforms | `supabase`, `notion`, `vercel`, `linear`, `sentry`, `socket`, `mercadopago` |
| Docs | `cloudflare-docs`, `astro-docs` |

**Usage:** Copy desired server configs to your `~/.claude.json` or project `.mcp.json`

---

### permission-sync

**Purpose:** Keep Claude Code permissions consistent across all your projects.

**What it does:**
- **Auto-learns:** When you allow a new permission in any project, it saves it to a central base file
- **Auto-syncs:** On session start, merges base permissions into the current project
- **Bidirectional:** Permissions flow from projects to base AND from base to projects

**What it doesn't do:**
- Doesn't override project-specific denials
- Doesn't sync without your consent (you approve permissions first)

**How it works:**

```
Project A: You allow "Bash(pnpm test:*)"
    ↓
Base permissions updated (auto-learn)
    ↓
Project B: On SessionStart, gets "Bash(pnpm test:*)" merged in
```

**Commands:**

| Command | Description |
|---------|-------------|
| `/sync-permissions` | Manual sync with `--all` or `--dry-run` options |
| `/show-permissions` | Compare base vs project permissions |

**Files:**
- Base: `~/.claude/plugins/.../permission-sync/templates/base-permissions.json`
- Project: `.claude/settings.local.json`

**Hook:** Runs on SessionStart (silent, logs to `~/.claude/permissions-sync.log`)

---

### knowledge-sync

**Purpose:** Sync reusable agents, skills, commands, docs, and templates from an external repository.

**What it does:**
- Clones [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) to local cache
- Auto-detects project dependencies (package.json) to suggest relevant components
- Copies selected components into your project's `.claude/` directory
- Tracks what's installed per project in a registry
- Notifies when updates are available

**What it doesn't do:**
- Doesn't auto-install components (you choose what to install)
- Doesn't modify your code (only adds to `.claude/` directory)

**Command:**

```bash
/knowledge-sync <subcommand>
```

| Subcommand | Description |
|------------|-------------|
| `setup` | Clone knowledge repo, create config and registry |
| `install --detect` | Analyze project, suggest components, install selected |
| `install --component X` | Install a specific component |
| `install --tag frontend` | Install all components with a tag |
| `sync` | Pull updates and sync to current project |
| `sync --all` | Sync all registered projects |
| `remove X` | Remove a component from project |
| `remove --all` | Remove all components from project |
| `list` | Show all available components |
| `status` | Show what's installed in current project |
| `status --all` | Show all registered projects |

**Hook:** On SessionStart, checks for updates and notifies if available

**Files:**
- Config: `~/.claude/knowledge-sync/config.json`
- Registry: `~/.claude/knowledge-sync/registry.json`
- Cache: `~/.claude/knowledge-sync/cache/` (cloned repo)

---

### session-tools

**Purpose:** Session journaling and reflection tools.

**What it does:**
- Creates structured diary entries from session transcripts
- Analyzes diary entries to identify patterns
- Suggests CLAUDE.md improvements based on patterns
- Auto-prompts for diary entry before context compaction

**What it doesn't do:**
- Doesn't auto-save (you review and save)
- Doesn't modify CLAUDE.md without your approval

**Commands:**

| Command | Description |
|---------|-------------|
| `/diary` | Create a structured diary entry from current session |
| `/reflect` | Analyze diary entries, identify patterns, propose CLAUDE.md updates |

**Hook:** On PreCompact, reminds you to create a diary entry

**Integration:** Works with `claude-mem` plugin if installed

---

### claude-initializer

**Purpose:** Initialize new projects with Claude Code configuration.

**What it does:**
- Generates CLAUDE.md with project-specific rules
- Creates `.claude/` directory structure
- Provides settings.local.json template with permission allowlists
- Optionally configures brand settings (colors, typography, tone)

**What it doesn't do:**
- Doesn't overwrite existing CLAUDE.md (merges with sentinel comments)
- Doesn't make architectural decisions

**Command:**

```bash
/init-project
```

**Templates:**
- `global.md.template` - Base CLAUDE.md template
- `global-rules-block.md.template` - Mergeable rules with sentinel comments
- `settings-template.json` - Permission allowlists/denylists
- `brand-config.json.template` - Brand configuration (colors, fonts, tone)

---

## Knowledge Repository

The [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) repository contains reusable components:

| Type | Count | Examples |
|------|-------|----------|
| Agents | 20 | `react-senior-dev`, `tech-lead`, `qa-engineer` |
| Skills | 43 | `react-patterns`, `drizzle-patterns`, `security-audit` |
| Commands | 17 | `/commit`, `/code-review`, `/security-review` |
| Docs | 11 | `code-standards`, `testing-standards`, `api-design` |
| Templates | 4 | `brand-config`, `code-review.yml` |

**Auto-detection:** The `knowledge-sync` plugin analyzes your `package.json` and suggests components based on your dependencies:

```
package.json has "react" → suggests react-patterns, react-senior-dev
package.json has "drizzle-orm" → suggests drizzle-patterns, db-drizzle-engineer
```

---

## Usage in Projects

### New Project Setup

```bash
# 1. Initialize Claude Code structure
/init-project

# 2. Setup knowledge sync (first time only)
/knowledge-sync setup

# 3. Install components based on your stack
/knowledge-sync install --detect

# 4. Permissions sync automatically on session start
```

### Daily Workflow

```bash
# Start working - hooks run automatically:
# - permission-sync: merges base permissions
# - knowledge-sync: checks for updates
# - task-master: shows active work

# Create a spec for new work
/spec "Add user authentication with OAuth"

# Work on tasks
/next-task

# Before ending session
/diary
```

### Updating Components

```bash
# Check for knowledge updates
/knowledge-sync status

# Sync updates to current project
/knowledge-sync sync

# Or sync all registered projects
/knowledge-sync sync --all
```

---

## Configuration

### Directory Structure (User Level)

```
~/.claude/
  plugins/
    cache/
      qazuor-claude-code-plugins/
        notifications/
        task-master/
        mcp-servers/
        permission-sync/
        knowledge-sync/
        session-tools/
        claude-initializer/
    marketplaces/
      qazuor-claude-code-plugins/
    installed_plugins.json
  knowledge-sync/
    config.json      # Knowledge repo URL, cache path
    registry.json    # Per-project component tracking
    cache/           # Cloned knowledge repo
  permissions-sync.log
```

### Directory Structure (Project Level)

```
your-project/
  .claude/
    CLAUDE.md           # Project instructions
    settings.local.json # Project permissions
    agents/             # From knowledge-sync
    skills/             # From knowledge-sync
    commands/           # From knowledge-sync
    docs/               # From knowledge-sync
    tasks/              # From task-master
      index.json
      specs/
      state/
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to create new plugins.

See [PLUGIN-FORMAT.md](PLUGIN-FORMAT.md) for the plugin format specification.

---

## License

MIT
