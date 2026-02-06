# Plugin Catalog

Complete inventory of all components in the claude-code-plugins repository (v2.0.0).

> **Note:** Knowledge components (20 agents, 43 skills, 17 commands, 11 docs, 4 templates = 95 total) live in the separate [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) repository and are managed by the **knowledge-sync** plugin.

## Quick Links

- [Summary](#summary)
- [knowledge-sync](#knowledge-sync)
- [permission-sync](#permission-sync)
- [session-tools](#session-tools)
- [claude-initializer](#claude-initializer)
- [notifications](#notifications)
- [task-master](#task-master)
- [mcp-servers](#mcp-servers)
- [Knowledge Repository](#knowledge-repository-external)

---

## Summary

| Plugin | Commands | Hooks | Scripts | Skills | Agents | Templates | MCP | Total |
|--------|----------|-------|---------|--------|--------|-----------|-----|-------|
| [knowledge-sync](#knowledge-sync) | 1 | 1 | 3 | 0 | 0 | 2 | 0 | 7 |
| [permission-sync](#permission-sync) | 2 | 1 | 2 | 0 | 0 | 1 | 0 | 6 |
| [session-tools](#session-tools) | 2 | 1 | 2 | 0 | 0 | 0 | 0 | 5 |
| [claude-initializer](#claude-initializer) | 1 | 0 | 0 | 0 | 0 | 4 | 0 | 5 |
| [notifications](#notifications) | 0 | 3 | 3 | 0 | 0 | 0 | 0 | 6 |
| [task-master](#task-master) | 6 | 1 | 1 | 7 | 3 | 7 | 0 | 25 |
| [mcp-servers](#mcp-servers) | 0 | 0 | 1 | 0 | 0 | 0 | 30 | 31 |
| **Total** | **12** | **7** | **12** | **7** | **3** | **14** | **30** | **85** |

---

## knowledge-sync

**Version:** 2.0.0

Manages installation, updates, and synchronization of knowledge components from the [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) repository. Detects project technologies and suggests relevant components automatically.

### Commands (1)

| Name | Description |
|------|-------------|
| `/knowledge-sync` | Unified command with subcommands: `setup`, `install`, `sync`, `remove`, `list`, `status` |

**Subcommands:**

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

### Hooks (1)

| Name | Event | Description |
|------|-------|-------------|
| check-updates | SessionStart | Checks for knowledge updates on session start, notifies if available |

### Scripts (3)

| Name | Description |
|------|-------------|
| `check-updates.sh` | Compares installed versions against registry, notifies of available updates |
| `sync.sh` | Downloads and installs knowledge components from the repository |
| `detect.sh` | Scans project files (package.json) to detect technologies and suggest matching components |

### Templates (2)

| Name | Description |
|------|-------------|
| `config-schema.json` | JSON Schema for `~/.claude/knowledge-sync/config.json` |
| `registry-schema.json` | JSON Schema for `~/.claude/knowledge-sync/registry.json` |

---

## permission-sync

**Version:** 2.0.0

Synchronizes Claude Code permissions across projects. Provides bidirectional sync: learns new permissions from projects and applies base permissions to all projects.

### Commands (2)

| Name | Description |
|------|-------------|
| `/sync-permissions` | Apply base permissions to current project. Options: `--all` (all projects), `--dry-run` (preview) |
| `/show-permissions` | Display current permission rules and diff against base template |

### Hooks (1)

| Name | Event | Description |
|------|-------|-------------|
| permissions-sync | SessionStart | Auto-learns new permissions and syncs base to project |

### Scripts (2)

| Name | Description |
|------|-------------|
| `permissions-sync.sh` | Main sync script: extracts new permissions, adds to base, merges to project |
| `permissions-sync-all.sh` | Batch sync with `--all` and `--dry-run` support |

### Templates (1)

| Name | Description |
|------|-------------|
| `base-permissions.json` | Base permission rules (allow/ask/deny arrays) synchronized across all projects |

---

## session-tools

**Version:** 2.0.0

Session lifecycle utilities: diary entries for session context preservation and reflection prompts for identifying patterns and improving CLAUDE.md.

### Commands (2)

| Name | Description |
|------|-------------|
| `/diary` | Create a structured diary entry from the current session transcript |
| `/reflect` | Analyze diary entries, identify patterns, propose CLAUDE.md updates |

### Hooks (1)

| Name | Event | Description |
|------|-------|-------------|
| pre-compact-diary | PreCompact | Prompts user to create diary entry before context compaction |

### Scripts (2)

| Name | Description |
|------|-------------|
| `pre-compact-diary.sh` | Outputs prompt reminding user to create diary entry |
| `claude-mem-watchdog.sh` | Monitors claude-mem integration health (if installed) |

---

## claude-initializer

**Version:** 2.0.0

Project bootstrapping: generates CLAUDE.md files, settings templates, and brand configuration for new or existing projects.

### Commands (1)

| Name | Description |
|------|-------------|
| `/init-project` | Interactive project initialization wizard |

### Templates (4)

| Name | Description |
|------|-------------|
| `global.md.template` | CLAUDE.md template for global (`~/.claude/`) settings |
| `global-rules-block.md.template` | Reusable rules block with sentinel comments for safe merging |
| `settings-template.json` | Claude Code `settings.local.json` template with permission allowlists |
| `brand-config.json.template` | Brand voice, colors, typography, and tone configuration |

---

## notifications

**Version:** 1.0.0

Desktop notifications and audio feedback for session events: completion beeps, TTS announcements, and subagent alerts.

### Hooks (3)

| Name | Event | Description |
|------|-------|-------------|
| on-notification | Notification | Desktop notification + TTS audio via Piper |
| stop-beep | Stop | Main session completion beep (1000Hz, 0.2s) |
| subagent-beep | SubagentStop | Subagent completion beep (800Hz, 0.1s) |

### Scripts (3)

| Name | Description |
|------|-------------|
| `on-notification.sh` | Cross-platform notifications (Linux/macOS/WSL) with optional Piper TTS |
| `stop-beep.sh` | Generates 1000Hz sine wave beep using paplay/afplay/PowerShell |
| `subagent-beep.sh` | Generates 800Hz sine wave beep for subagent completion |

**Platform Support:**

| Platform | Notification | Audio |
|----------|--------------|-------|
| Linux | notify-send | paplay |
| macOS | osascript | afplay |
| WSL | PowerShell | PowerShell |

---

## task-master

**Version:** 1.0.0

Full-featured task management pipeline: from specs to atomic tasks with dependency tracking, complexity scoring, and quality gates.

### Agents (3)

| Name | Description |
|------|-------------|
| `spec-writer` | Generates functional specs with user stories, acceptance criteria, and scope definition |
| `tech-analyzer` | Technical analysis: architecture design, data models, API design, risk assessment |
| `task-planner` | Decomposes specs into atomic tasks with dependencies, phases, and complexity scores |

### Commands (6)

| Name | Description |
|------|-------------|
| `/spec` | Create specification from requirements (uses spec-writer agent) |
| `/tasks` | Task dashboard with progress bars and status overview |
| `/next-task` | Find and start the next available task based on dependencies |
| `/new-task` | Create standalone task (no spec required) |
| `/task-status` | Detailed progress report with dependency graph |
| `/replan` | Modify task plans: add, remove, reorder, split tasks |

### Skills (7)

| Name | Description |
|------|-------------|
| `complexity-scorer` | Weighted 8-factor scoring (1-10) with hard ceiling of 4 for atomic tasks |
| `overlap-detector` | Detects duplicate work between specs and tasks |
| `dependency-grapher` | DAG validation, cycle detection, critical path, parallel tracks |
| `quality-gate` | Runs lint/typecheck/test before marking task complete |
| `task-atomizer` | Breaks features into atomic sub-tasks by phase and layer |
| `task-from-spec` | Orchestrates atomizer + scorer + grapher from spec |
| `spec-generator` | Transforms Plan Mode output into formal spec documents |

### Hooks (1)

| Name | Event | Description |
|------|-------|-------------|
| session-resume | SessionStart | Detects active work and displays summary |

### Scripts (1)

| Name | Description |
|------|-------------|
| `session-resume.sh` | Reads task index, displays active epics and pending tasks |

### Templates (7)

| Name | Description |
|------|-------------|
| `spec-full.md` | Full complexity spec template (large features) |
| `spec-lite.md` | Medium complexity spec template (smaller features) |
| `state-schema.json` | JSON Schema for task state files |
| `metadata-schema.json` | JSON Schema for spec metadata |
| `index-schema.json` | JSON Schema for global task index |
| `specs-index-schema.json` | JSON Schema for specs index |
| `config-example.json` | Example quality gate configuration |

---

## mcp-servers

**Version:** 1.0.0

Pre-configured MCP (Model Context Protocol) server definitions ready for inclusion in Claude Code settings. 30 servers covering reasoning, documentation, search, file operations, browsers, databases, cloud services, and integrations.

### MCP Servers (30)

#### Thinking and Analysis

| Server | Package | API Key |
|--------|---------|---------|
| `sequential-thinking` | @modelcontextprotocol/server-sequential-thinking | No |
| `context7` | @upstash/context7-mcp@latest | No |

#### Search and Knowledge

| Server | Package | API Key |
|--------|---------|---------|
| `perplexity-ask` | server-perplexity-ask | PERPLEXITY_API_KEY |
| `brave-search` | @modelcontextprotocol/server-brave-search | BRAVE_API_KEY |

#### Data and Code

| Server | Package | API Key |
|--------|---------|---------|
| `json` | @berrydev-ai/json-mcp-server | No |
| `drizzle` | github:defrex/drizzle-mcp | No |
| `shadcn` | HTTP: `https://www.shadcn.io/api/mcp` | No |

#### Filesystem and VCS

| Server | Package | API Key |
|--------|---------|---------|
| `filesystem` | @modelcontextprotocol/server-filesystem | No |
| `git` | @cyanheads/git-mcp-server@latest | No |

#### GitHub

| Server | Package | API Key |
|--------|---------|---------|
| `github` | @modelcontextprotocol/server-github | GITHUB_TOKEN |

#### Browser Testing

| Server | Package | API Key |
|--------|---------|---------|
| `playwright` | @playwright/mcp@latest | No |
| `puppeteer` | @modelcontextprotocol/server-puppeteer | No |
| `chrome-devtools` | chrome-devtools-mcp | No |

#### Containers

| Server | Package | API Key |
|--------|---------|---------|
| `docker` | uvx mcp-server-docker | No |

#### Databases

| Server | Package | API Key |
|--------|---------|---------|
| `postgres` | @henkey/postgres-mcp-server | DATABASE_URL |
| `sqlite` | uvx mcp-sqlite | SQLITE_DB_PATH |
| `prisma` | npx prisma mcp | No |
| `neon` | HTTP: `https://mcp.neon.tech/mcp` | NEON_API_KEY |

#### Cache

| Server | Package | API Key |
|--------|---------|---------|
| `redis-upstash` | @upstash/mcp-server | UPSTASH_REDIS_REST_URL, UPSTASH_REDIS_REST_TOKEN |

#### Dev Tools

| Server | Package | API Key |
|--------|---------|---------|
| `memory` | @modelcontextprotocol/server-memory | No |
| `@21st-dev/magic` | @21st-dev/magic@latest | TWENTYFIRST_API_KEY |

#### Design

| Server | Package | API Key |
|--------|---------|---------|
| `figma` | figma-mcp | FIGMA_TOKEN |

#### Testing

| Server | Package | API Key |
|--------|---------|---------|
| `browserstack` | @browserstack/mcp-server@latest | BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY |

#### Platforms (HTTP)

| Server | URL | API Key |
|--------|-----|---------|
| `supabase` | `https://mcp.supabase.com` | OAuth |
| `notion` | `https://mcp.notion.com` | OAuth |
| `vercel` | `https://mcp.vercel.com/` | OAuth |
| `linear` | `https://mcp.linear.app/mcp` | OAuth |
| `sentry` | `https://mcp.sentry.dev/mcp` | OAuth |
| `socket` | `https://mcp.socket.dev/` | OAuth |
| `mercadopago` | `https://mcp.mercadopago.com/mcp` | OAuth |

#### Documentation (HTTP)

| Server | URL | API Key |
|--------|-----|---------|
| `cloudflare-docs` | `https://docs.mcp.cloudflare.com/mcp` | No |
| `astro-docs` | `https://mcp.docs.astro.build/mcp` | No |

### Scripts (1)

| Name | Description |
|------|-------------|
| `check-deps.sh` | Verifies required binaries (npx, uvx) and environment variables for selected servers |

---

## Knowledge Repository (External)

Components live in [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) and are managed by the knowledge-sync plugin.

### Summary

| Type | Count |
|------|-------|
| Agents | 20 |
| Skills | 43 |
| Commands | 17 |
| Docs | 11 |
| Templates | 4 |
| **Total** | **95** |

### Agents (20)

**Core:**
code-reviewer, content-writer, debugger, design-reviewer, devops-engineer, node-typescript-engineer, product-functional, product-technical, qa-engineer, tech-lead, ux-ui-designer

**Frontend:**
astro-engineer, design-cloner, nextjs-engineer, react-senior-dev, tanstack-start-engineer

**Backend:**
db-drizzle-engineer, hono-engineer, nestjs-engineer, prisma-engineer

### Skills (43)

**Core (24):** accessibility-audit, api-app-testing, ci-cd-patterns, env-validation, error-handling-patterns, frontend-design, git-commit-helper, i18n-patterns, json-data-auditor, markdown-formatter, mermaid-diagram-specialist, monorepo-patterns, performance-audit, performance-testing, qa-criteria-validator, react-performance, security-audit, security-testing, seo-patterns, tdd-methodology, tech-writing, web-app-testing, zod-patterns

**Frontend (13):** astro-patterns, design-to-components, nextjs-patterns, react-hook-form-patterns, react-patterns, shadcn-specialist, tanstack-patterns, tanstack-query-patterns, tanstack-router-patterns, tanstack-table-patterns, vercel-react-best-practices, vercel-specialist, zustand-patterns

**Backend (4):** drizzle-patterns, hono-patterns, nestjs-patterns, prisma-patterns

**Shared (3):** better-auth-patterns, docker-patterns, github-actions-patterns

### Commands (17)

accessibility-audit, add-new-entity, check-deps, code-check, code-review, commit, design-review, five-why, format-markdown, generate-changelog, init-project, performance-audit, quality-check, run-tests, security-audit, security-review, update-docs

### Docs (11)

api-design-standards, architecture-patterns, atomic-commits, code-standards, development-workflow, documentation-standards, glossary, performance-standards, quick-start, security-standards, testing-standards

### Templates (4)

brand-config.json.template, code-review.yml, project-generic.md.template, security-review.yml

---

## Totals

### This Repository (Plugins)

| Type | Count |
|------|-------|
| Commands | 12 |
| Hooks | 7 |
| Scripts | 12 |
| Skills | 7 |
| Agents | 3 |
| Templates | 14 |
| MCP Servers | 30 |
| **Total** | **85** |

### Knowledge Repository (External)

| Type | Count |
|------|-------|
| Agents | 20 |
| Skills | 43 |
| Commands | 17 |
| Docs | 11 |
| Templates | 4 |
| **Total** | **95** |

### Combined Total: 180 components
