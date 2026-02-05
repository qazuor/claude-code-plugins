# Plugin Catalog

Complete inventory of all components in the claude-code-plugins repository (v2.0.0).

> **Note:** Knowledge components (20 agents, 43 skills, 17 commands, 11 docs, 4 templates = 95 total) now live in the separate [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) repository. This catalog only covers operational plugins.

## Summary

| Plugin | Commands | Hooks | Scripts | Skills | Agents | Templates | MCP | Total |
|--------|----------|-------|---------|--------|--------|-----------|-----|-------|
| knowledge-sync | 1 | 1 | 3 | 0 | 0 | 2 | 0 | 7 |
| permission-sync | 2 | 1 | 2 | 0 | 0 | 1 | 0 | 6 |
| session-tools | 2 | 1 | 2 | 0 | 0 | 0 | 0 | 5 |
| claude-initializer | 1 | 0 | 0 | 0 | 0 | 4 | 0 | 5 |
| notifications | 0 | 3 | 3 | 0 | 0 | 0 | 0 | 6 |
| task-master | 6 | 1 | 1 | 7 | 3 | 7 | 0 | 25 |
| mcp-servers | 0 | 0 | 1 | 0 | 0 | 0 | 30 | 31 |
| **Total** | **12** | **7** | **12** | **7** | **3** | **14** | **30** | **85** |

---

## knowledge-sync@qazuor

Manages installation, updates, and synchronization of knowledge packs from the claude-code-knowledge registry. Detects project technologies and suggests relevant packs automatically.

### Commands (1)

| Name | Description |
|------|-------------|
| /knowledge-sync | Unified command with subcommands.. setup, install, sync, remove, list, status |

### Hooks (1)

| Name | Event | Description |
|------|-------|-------------|
| check-updates | SessionStart | Checks for knowledge pack updates on session start |

### Scripts (3)

| Name | Description |
|------|-------------|
| check-updates.sh | Compares installed versions against registry, notifies of available updates |
| sync.sh | Downloads and installs knowledge packs from the registry |
| detect.sh | Scans project files to detect technologies and suggest matching packs |

### Templates (2)

| Name | Description |
|------|-------------|
| config-schema.json | JSON Schema for knowledge-sync local configuration |
| registry-schema.json | JSON Schema for the knowledge pack registry format |

---

## permission-sync@qazuor

Synchronizes Claude Code permission rules (.claude/settings.json) across projects. Provides a base template and tools to apply, diff, and manage permissions consistently.

### Commands (2)

| Name | Description |
|------|-------------|
| /sync-permissions | Apply base permissions template to current project |
| /show-permissions | Display current permission rules and diff against base template |

### Hooks (1)

| Name | Event | Description |
|------|-------|-------------|
| permissions-sync | SessionStart | Auto-syncs permissions on session start |

### Scripts (2)

| Name | Description |
|------|-------------|
| permissions-sync.sh | Syncs permissions for the current project |
| permissions-sync-all.sh | Batch-syncs permissions across all configured projects |

### Templates (1)

| Name | Description |
|------|-------------|
| base-permissions.json | Base permission rules template applied to all projects |

---

## session-tools@qazuor

Session lifecycle utilities.. diary entries for session context and reflection prompts for compact-safe summaries.

### Commands (2)

| Name | Description |
|------|-------------|
| /diary | Create or append a diary entry for the current session |
| /reflect | Generate a structured reflection of the current session state |

### Hooks (1)

| Name | Event | Description |
|------|-------|-------------|
| pre-compact-diary | PreCompact | Writes a diary snapshot before context compaction |

### Scripts (2)

| Name | Description |
|------|-------------|
| pre-compact-diary.sh | Captures session state into a diary entry before compaction |
| claude-mem-watchdog.sh | Monitors claude-mem integration health |

---

## claude-initializer@qazuor

Project bootstrapping.. generates CLAUDE.md files, settings templates, and brand configuration for new or existing projects.

### Commands (1)

| Name | Description |
|------|-------------|
| /init-project | Interactive project initialization wizard |

### Templates (4)

| Name | Description |
|------|-------------|
| global.md.template | CLAUDE.md template for global (~/.claude/) settings |
| global-rules-block.md.template | Reusable rules block for inclusion in global CLAUDE.md |
| settings-template.json | Claude Code settings.json template |
| brand-config.json.template | Brand voice and identity configuration |

---

## notifications@qazuor

Desktop notifications and audio feedback for session events.. completion beeps, TTS announcements, and subagent alerts.

### Hooks (3)

| Name | Event | Description |
|------|-------|-------------|
| on-notification | Notification | Desktop notification + TTS audio via piper |
| stop-beep | Stop | Main session completion beep |
| subagent-beep | SubagentStop | Subagent completion beep |

### Scripts (3)

| Name | Description |
|------|-------------|
| on-notification.sh | notify-send + piper TTS with OS detection |
| stop-beep.sh | 1000Hz sine wave (0.2s) |
| subagent-beep.sh | 800Hz sine wave (0.1s) |

---

## task-master@qazuor

Full-featured task management pipeline.. from specs to atomic tasks with dependency tracking, complexity scoring, and quality gates.

### Agents (3)

| Name | Description |
|------|-------------|
| spec-writer | Functional specs with user stories and BDD criteria |
| tech-analyzer | Technical analysis, architecture, risk assessment |
| task-planner | Decomposes specs into atomic tasks with dependencies |

### Commands (6)

| Name | Description |
|------|-------------|
| /spec | Create specification from requirements |
| /tasks | Task dashboard with progress bars |
| /next-task | Find and start next available task |
| /new-task | Create standalone task |
| /task-status | Detailed progress report |
| /replan | Modify task plans |

### Skills (7)

| Name | Description |
|------|-------------|
| complexity-scorer | Weighted 8-factor complexity scoring (1-10) |
| overlap-detector | Detects duplicate work between specs |
| dependency-grapher | DAG validation, critical path, parallel tracks |
| quality-gate | Lint/typecheck/test before task completion |
| task-atomizer | Breaks features into atomic sub-tasks |
| task-from-spec | Orchestrates atomizer + scorer + grapher |
| spec-generator | Transforms plans into formal specs |

### Hooks (1)

| Name | Event | Description |
|------|-------|-------------|
| session-resume | SessionStart | Restores task context on session start |

### Scripts (1)

| Name | Description |
|------|-------------|
| session-resume.sh | Loads active task state into session context |

### Templates (7)

| Name | Description |
|------|-------------|
| spec-lite.md | Medium complexity spec template |
| spec-full.md | High complexity spec template |
| state-schema.json | Task state JSON Schema |
| metadata-schema.json | Spec metadata JSON Schema |
| index-schema.json | Global task index JSON Schema |
| specs-index-schema.json | Specs index JSON Schema |
| config-example.json | Quality gate configuration |

---

## mcp-servers@qazuor

Pre-configured MCP server definitions ready for inclusion in Claude Code settings. 30 servers covering reasoning, documentation, search, file ops, browsers, databases, cloud services, and integrations.

### MCP Servers (30)

| Server | Category | API Key |
|--------|----------|---------|
| sequential-thinking | Reasoning | No |
| context7 | Documentation | No |
| perplexity-ask | Web Search | Yes |
| filesystem | File Operations | No |
| git | Version Control | No |
| json | Data Processing | No |
| playwright | Browser Automation | No |
| chrome-devtools | Browser Debugging | No |
| docker | Containers | No |
| neon | PostgreSQL (Cloud) | Yes |
| postgres | PostgreSQL (Local) | Connection |
| sqlite | SQLite | Path |
| linear | Issue Tracking | Yes |
| github | GitHub Integration | Yes |
| vercel | Deployment | Yes |
| supabase | BaaS | Yes |
| @21st-dev/magic | Code Generation | Yes |
| shadcn-ui | Component Library | No |
| figma | Design | Yes |
| drizzle | ORM | No |
| mercadopago | Payments | Yes |
| sentry | Error Monitoring | Yes |
| socket | Dependency Security | Yes |
| cloudflare-docs | CDN Documentation | No |
| browserstack | Browser Testing | Yes |
| brave-search | Web Search | Yes |
| notion | Notes/Wiki | Yes |
| slack | Messaging | Yes |
| redis-upstash | Cache/Queue | Yes |
| prisma | ORM | No |

### Scripts (1)

| Name | Description |
|------|-------------|
| check-deps.sh | Verifies required binaries and API keys for selected MCP servers |
