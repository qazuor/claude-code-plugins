# Claude Code Plugins Marketplace

[![CI](https://github.com/qazuor/claude-code-plugins/actions/workflows/ci.yml/badge.svg)](https://github.com/qazuor/claude-code-plugins/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Plugins](https://img.shields.io/badge/Plugins-7-green.svg)](#plugins)
[![Components](https://img.shields.io/badge/Components-159-orange.svg)](#plugins)

A curated collection of plugins for [Claude Code](https://claude.ai/claude-code) — Anthropic's official CLI tool. Provides agents, commands, skills, hooks, templates, and MCP server configurations for professional software development.

## Quick Start

```bash
git clone https://github.com/qazuor/claude-code-plugins.git
cd claude-code-plugins
./installer/install.sh --profile full-stack
```

## Plugins

| Plugin | Description | Components |
|--------|-------------|------------|
| **core** | Universal agents, commands, skills, docs, templates | 74 |
| **notifications** | Desktop notifications, TTS audio, stop beeps | 6 |
| **frameworks-frontend** | Frontend framework agents and skills (React, Next.js, Astro, TanStack, and UI libraries) | 15 |
| **frameworks-backend** | Backend framework agents and skills (NestJS, Hono, Drizzle, Prisma) | 8 |
| **frameworks-shared** | Shared infrastructure skills (Docker, GitHub Actions) | 2 |
| **task-master** | Planning, specs, task management, quality gates | 24 |
| **mcp-servers** | 30 pre-configured MCP server definitions | 30 |

**Total: 159 components across 7 plugins**

## Installation

### Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI installed
- `jq` for JSON processing (`sudo apt install jq` or `brew install jq`)
- Node.js 18+ (for MCP servers)

### User-Level Install (all projects)

```bash
# Full development toolkit (all plugins)
./installer/install.sh --profile full-stack

# Core essentials only
./installer/install.sh --profile minimal

# Backend development (Core + backend frameworks + shared + task-master)
./installer/install.sh --profile backend-only

# Frontend development (Core + frontend frameworks + shared + task-master)
./installer/install.sh --profile frontend-only
```

### Project-Level Install (single project)

Install plugins only for a specific project instead of globally:

```bash
# Install into the current project directory
cd /path/to/your/project
/path/to/claude-code-plugins/installer/install.sh --profile full-stack --project

# Or specify the project directory explicitly
./installer/install.sh --profile minimal --project /path/to/your/project
```

This creates symlinks in the project's `.claude/` directory, merges hooks into `.claude/settings.local.json`, and MCP servers into `.mcp.json`. Only that project will have access to the plugins.

### Install Specific Plugins

```bash
./installer/install.sh --enable core --enable notifications
```

### Configure MCP API Keys

```bash
./installer/install.sh --profile full-stack --setup-mcp
```

### Update

```bash
cd claude-code-plugins && git pull
# Symlinks mean updates are instant — no reinstall needed
```

### Uninstall

```bash
# User-level
./installer/uninstall.sh

# Project-level
./installer/uninstall.sh --project /path/to/your/project
```

## Plugin Details

### Core (`core@qazuor`)

Universal tools for any software project.

**11 Agents** — AI personas with domain expertise:
- `tech-lead` — Architectural oversight, code quality, security
- `product-functional` — PDR creation, user stories, acceptance criteria
- `product-technical` — Technical analysis, architecture design
- `qa-engineer` — Test planning, quality gates, coverage tracking
- `debugger` — Bug investigation, root cause analysis (Five Whys)
- `content-writer` — UX copywriting, brand voice, multilingual content
- `ux-ui-designer` — UI design, user flows, WCAG accessibility
- `node-typescript-engineer` — Node.js/TypeScript implementation
- `code-reviewer` — Systematic code review with pragmatic triage
- `devops-engineer` — CI/CD, Docker, deployment, infrastructure
- `design-reviewer` — Visual UI review with Playwright

**21 Commands** — Slash commands for common workflows:
- `/quality-check` — Master quality validation (lint + test + review)
- `/code-check` — Linting and type checking
- `/run-tests` — Test suite with coverage
- `/security-audit` — OWASP security assessment
- `/performance-audit` — Performance analysis
- `/accessibility-audit` — WCAG 2.1 AA compliance
- `/add-new-entity` — Scaffold new domain entity
- `/update-docs` — Comprehensive documentation update
- `/five-why` — Root cause analysis
- `/format-markdown` — Markdown formatting and linting
- `/commit` — Conventional commit message generation
- `/code-review` — Invoke code reviewer
- `/create-agent` — Create new agent wizard
- `/create-command` — Create new command wizard
- `/create-skill` — Create new skill wizard
- `/help` — Interactive help system
- `/init-project` — Initialize project configuration
- `/check-deps` — Dependency audit
- `/generate-changelog` — Changelog from git history
- `/security-review` — Enhanced security review with confidence scoring
- `/design-review` — Visual UI review

**23 Skills** — Reusable knowledge patterns:
- Testing: `tdd-methodology`, `api-app-testing`, `web-app-testing`, `performance-testing`, `security-testing`
- Quality: `qa-criteria-validator`, `security-audit`, `performance-audit`, `accessibility-audit`
- Patterns: `error-handling-patterns`, `zod-patterns`, `ci-cd-patterns`, `env-validation`, `monorepo-patterns`
- Documentation: `git-commit-helper`, `markdown-formatter`, `tech-writing`, `json-data-auditor`, `mermaid-diagram-specialist`
- Design: `frontend-design`, `react-performance`
- SEO/i18n: `i18n-patterns`, `seo-patterns`

**10 Docs** — Standards and references
**9 Templates** — Project scaffolding, CI/CD, brand configuration

### Notifications (`notifications@qazuor`)

Audio and visual alerts for Claude Code events.

- Desktop notifications via `notify-send` (Linux) / `terminal-notifier` (macOS)
- TTS audio via Piper with fallback to `espeak` / `say`
- Stop beeps for main session and subagent completion
- Auto-detects OS capabilities

### Frameworks Frontend (`frameworks-frontend@qazuor`)

Frontend framework expertise.

**4 Agents:**
- `react-senior-dev` — React 19, hooks, Server Components
- `nextjs-engineer` — Next.js App Router, SSR/ISR
- `astro-engineer` — Astro islands, SSG/SSR, Content Collections
- `tanstack-start-engineer` — TanStack Start full-stack

**11 Skills:**
- `react-patterns`, `react-hook-form-patterns`, `tanstack-query-patterns`
- `shadcn-specialist`, `zustand-patterns`, `tanstack-router-patterns`
- `tanstack-table-patterns`, `nextjs-patterns`, `astro-patterns`
- `vercel-specialist`, `tanstack-patterns`

### Frameworks Backend (`frameworks-backend@qazuor`)

Backend framework expertise.

**4 Agents:**
- `nestjs-engineer` — NestJS modules, DI, guards
- `hono-engineer` — Hono API routes, middleware, validation
- `db-drizzle-engineer` — Drizzle ORM schemas, migrations
- `prisma-engineer` — Prisma schema, Client API, migrations

**4 Skills:**
- `nestjs-patterns`, `hono-patterns`, `drizzle-patterns`, `prisma-patterns`

### Frameworks Shared (`frameworks-shared@qazuor`)

Shared infrastructure skills used across frontend and backend.

**2 Skills:**
- `docker-patterns` — Dockerfile, multi-stage builds, compose
- `github-actions-patterns` — Workflows, jobs, caching, matrix builds

### Task Master (`task-master@qazuor`)

End-to-end project planning and task management.

**Commands:** `/spec`, `/tasks`, `/next-task`, `/new-task`, `/task-status`, `/replan`

**Workflow:**
1. `/spec` — Create specification from requirements (auto-selects lite/full template)
2. Tasks are generated automatically with complexity scores and dependencies
3. `/next-task` — Get next available task (Quick Win or Critical Path strategy)
4. Quality gates run automatically before task completion
5. `/tasks` — Dashboard with progress bars and statistics

### MCP Servers (`mcp-servers@qazuor`)

30 pre-configured MCP server definitions.

**No API key required:** sequential-thinking, context7, filesystem, git, json, playwright, chrome-devtools, docker, cloudflare-docs, shadcn-ui, drizzle, prisma

**API key required:** perplexity-ask, github, vercel, linear, neon, sentry, brave-search, notion, slack, figma, mercadopago, supabase, socket, browserstack, redis-upstash, @21st-dev/magic

**Connection required:** postgres, sqlite

## Architecture

```
claude-code-plugins/
├── .github/workflows/      # CI/CD (JSON validation, ShellCheck, markdownlint)
├── installer/
│   ├── install.sh          # Main installer (symlinks to ~/.claude/plugins/cache/)
│   ├── uninstall.sh        # Clean removal
│   ├── update.sh           # Git pull + verify symlinks
│   └── profiles/           # Installation profiles (full-stack, minimal, etc.)
├── plugins/
│   ├── core/               # Universal agents, commands, skills, docs, templates
│   ├── notifications/      # Desktop + audio notification hooks
│   ├── frameworks-frontend/# Frontend framework agents and skills
│   ├── frameworks-backend/ # Backend framework agents and skills
│   ├── frameworks-shared/  # Shared infrastructure skills (Docker, GitHub Actions)
│   ├── task-master/        # Planning, specs, task management
│   └── mcp-servers/        # MCP server configurations
├── package.json
├── LICENSE                  # MIT
└── README.md
```

### How It Works

The installer creates **symlinks** from this repository to `~/.claude/plugins/cache/qazuor/`. This means:

- **Instant updates**: `git pull` immediately propagates changes to all projects
- **Single source of truth**: One repository, many projects
- **Zero configuration per project**: Plugins are always available
- **Easy rollback**: `git checkout` to any previous version

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to create new plugins, agents, commands, and skills.

See [PLUGIN-FORMAT.md](PLUGIN-FORMAT.md) for the plugin format specification.

## License

MIT
