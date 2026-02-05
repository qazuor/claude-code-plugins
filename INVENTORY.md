# Claude Code Plugins - Complete Inventory

## PLUGIN: knowledge-sync (v2.0.0)

### Commands (1)

- `knowledge-sync` .. Manage knowledge components with subcommands: setup, install, sync, remove, list, status

### Hooks (1)

- SessionStart .. `check-updates.sh` (checks for knowledge repository updates)

### Scripts (3)

- `check-updates.sh` .. Silent git pull + notify if updates available
- `sync.sh` .. Copy updated files from cache to project
- `detect.sh` .. Analyze package.json and suggest components

### Templates (2)

- `config-schema.json` .. JSON Schema for config.json
- `registry-schema.json` .. JSON Schema for registry.json

---

## PLUGIN: permission-sync (v2.0.0)

### Commands (2)

- `sync-permissions` .. Manually sync permissions between base and project (--all, --dry-run)
- `show-permissions` .. Display permission status: base vs project (--diff, --base, --project)

### Hooks (1)

- SessionStart .. `permissions-sync.sh` (auto-learn and sync permissions)

### Scripts (2)

- `permissions-sync.sh` .. Auto-learn new permissions and merge base into project
- `permissions-sync-all.sh` .. Manual sync with --all and --dry-run support

### Templates (1)

- `base-permissions.json` .. Base permissions synchronized across all projects

---

## PLUGIN: session-tools (v2.0.0)

### Commands (2)

- `diary` .. Create structured diary entry from current session
- `reflect` .. Analyze diary entries, identify patterns, propose CLAUDE.md updates

### Hooks (1)

- PreCompact .. `pre-compact-diary.sh` (auto-generate diary before compact)

### Scripts (2)

- `pre-compact-diary.sh` .. Instructs Claude to create diary entry before compaction
- `claude-mem-watchdog.sh` .. Health check and auto-restart for claude-mem worker

---

## PLUGIN: claude-initializer (v2.0.0)

### Commands (1)

- `init-project` .. Initialize project with CLAUDE.md, directory structure, and optional brand config

### Templates (4)

- `global.md.template` .. CLAUDE.md template for global settings
- `global-rules-block.md.template` .. Mergeable rules block with sentinel comments
- `settings-template.json` .. Claude Code settings template with permission allowlists
- `brand-config.json.template` .. Brand configuration template (colors, typography, tone)

---

## PLUGIN: notifications (v1.0.0)

### Hooks (3)

- Notification .. Desktop notifications + TTS audio (on-notification.sh)
- Stop .. 1000Hz beep on main session close (stop-beep.sh)
- SubagentStop .. 800Hz beep on subagent close (subagent-beep.sh)

### Scripts (3)

- `on-notification.sh` .. Cross-platform notifications (Linux/macOS/WSL) + Piper TTS
- `stop-beep.sh` .. Session end beep (1000Hz, 0.2s)
- `subagent-beep.sh` .. Subagent end beep (800Hz, 0.1s)

---

## PLUGIN: task-master (v1.0.0)

### Agents (3)

- `spec-writer` .. Generates functional specifications with user stories and BDD criteria
- `tech-analyzer` .. Technical analysis, architecture design, risk assessment
- `task-planner` .. Decomposes specs into atomic tasks with dependencies

### Commands (6)

- `spec` .. Create/edit specifications
- `tasks` .. Task dashboard with progress bars
- `next-task` .. Get next available task
- `new-task` .. Create standalone task
- `task-status` .. Detailed progress report
- `replan` .. Modify task plans

### Skills (7)

- `complexity-scorer` .. Weighted 8-factor complexity scoring (ceiling: 4)
- `dependency-grapher` .. DAG validation, critical path, parallel tracks
- `overlap-detector` .. Detects duplicate work between specs
- `quality-gate` .. Lint/typecheck/test before task completion
- `spec-generator` .. Transforms plans into formal specs
- `task-atomizer` .. Breaks features into atomic sub-tasks
- `task-from-spec` .. Orchestrates atomizer + scorer + grapher

### Hooks (1)

- SessionStart .. `session-resume.sh` (detects active work and shows summary)

### Templates (7)

- `spec-full.md` .. Full complexity spec template
- `spec-lite.md` .. Medium complexity spec template
- `index-schema.json` .. Global task index JSON Schema
- `specs-index-schema.json` .. Specs index JSON Schema
- `metadata-schema.json` .. Spec metadata JSON Schema
- `state-schema.json` .. Task state JSON Schema
- `config-example.json` .. Quality gate configuration example

---

## PLUGIN: mcp-servers (v1.0.0)

### MCP Servers (30)

**Thinking and Analysis:**
- `sequential-thinking` .. @modelcontextprotocol/server-sequential-thinking
- `context7` .. @upstash/context7-mcp@latest

**Search and Knowledge:**
- `perplexity-ask` .. server-perplexity-ask (requires PERPLEXITY_API_KEY)
- `brave-search` .. @modelcontextprotocol/server-brave-search (requires BRAVE_API_KEY)

**Data and Code:**
- `json` .. @berrydev-ai/json-mcp-server
- `drizzle` .. github:defrex/drizzle-mcp
- `shadcn` .. HTTP: `https://www.shadcn.io/api/mcp`

**Filesystem and VCS:**
- `filesystem` .. @modelcontextprotocol/server-filesystem
- `git` .. @cyanheads/git-mcp-server@latest

**GitHub:**
- `github` .. @modelcontextprotocol/server-github (requires GITHUB_TOKEN)

**Browser Testing:**
- `playwright` .. @playwright/mcp@latest
- `puppeteer` .. @modelcontextprotocol/server-puppeteer
- `chrome-devtools` .. chrome-devtools-mcp

**Containers:**
- `docker` .. uvx mcp-server-docker

**Databases:**
- `postgres` .. @henkey/postgres-mcp-server (requires DATABASE_URL)
- `sqlite` .. uvx mcp-sqlite (requires SQLITE_DB_PATH)
- `prisma` .. npx prisma mcp
- `neon` .. `https://mcp.neon.tech/mcp` (requires NEON_API_KEY)

**Cache:**
- `redis-upstash` .. @upstash/mcp-server (requires UPSTASH_REDIS_REST_URL, UPSTASH_REDIS_REST_TOKEN)

**Dev Tools:**
- `memory` .. @modelcontextprotocol/server-memory
- `@21st-dev/magic` .. @21st-dev/magic@latest (requires TWENTYFIRST_API_KEY)

**Design:**
- `figma` .. figma-mcp (requires FIGMA_TOKEN)

**Testing:**
- `browserstack` .. @browserstack/mcp-server@latest (requires BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY)

**Platforms (HTTP):**
- `supabase` .. `https://mcp.supabase.com`
- `notion` .. `https://mcp.notion.com`
- `vercel` .. `https://mcp.vercel.com/`
- `linear` .. `https://mcp.linear.app/mcp`
- `sentry` .. `https://mcp.sentry.dev/mcp`
- `socket` .. `https://mcp.socket.dev/`
- `mercadopago` .. `https://mcp.mercadopago.com/mcp`

**Docs (HTTP):**
- `cloudflare-docs` .. `https://docs.mcp.cloudflare.com/mcp`
- `astro-docs` .. `https://mcp.docs.astro.build/mcp`

### Scripts (1)

- `check-deps.sh` .. Verify MCP server dependencies

---

## KNOWLEDGE REPOSITORY (external)

Components live in [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) and are managed by the knowledge-sync plugin.

- **Agents (20)**: code-reviewer, content-writer, debugger, design-reviewer, devops-engineer, node-typescript-engineer, product-functional, product-technical, qa-engineer, tech-lead, ux-ui-designer, astro-engineer, design-cloner, nextjs-engineer, react-senior-dev, tanstack-start-engineer, db-drizzle-engineer, hono-engineer, nestjs-engineer, prisma-engineer
- **Skills (43)**: 24 core + 13 frontend + 4 backend + 3 shared
- **Commands (17)**: accessibility-audit, add-new-entity, check-deps, code-check, code-review, commit, design-review, five-why, format-markdown, generate-changelog, init-project, performance-audit, quality-check, run-tests, security-audit, security-review, update-docs
- **Docs (11)**: api-design-standards, architecture-patterns, atomic-commits, code-standards, development-workflow, documentation-standards, glossary, performance-standards, quick-start, security-standards, testing-standards
- **Templates (4)**: brand-config.json.template, code-review.yml, project-generic.md.template, security-review.yml

---

## TOTALS

### This Repository (plugins)

- Commands: 12
- Hooks: 7
- Scripts: 12
- Skills: 7
- Agents: 3
- Templates: 14
- MCP Servers: 30
- **Total plugin components: 85**

### Knowledge Repository (external)

- Agents: 20
- Skills: 43
- Commands: 17
- Docs: 11
- Templates: 4
- **Total knowledge components: 95**

### Combined Total: 180
