# Plugin Catalog

Complete inventory of all components across all plugins.

## Summary

| Plugin | Agents | Commands | Skills | Hooks | Docs | Templates | MCP | Total |
|--------|--------|----------|--------|-------|------|-----------|-----|-------|
| core | 11 | 21 | 23 | 0 | 10 | 9 | 0 | 74 |
| notifications | 0 | 0 | 0 | 3 | 0 | 0 | 0 | 6 |
| frameworks-frontend | 4 | 0 | 11 | 0 | 0 | 0 | 0 | 15 |
| frameworks-backend | 4 | 0 | 4 | 0 | 0 | 0 | 0 | 8 |
| frameworks-shared | 0 | 0 | 2 | 0 | 0 | 0 | 0 | 2 |
| task-master | 3 | 6 | 7 | 1 | 0 | 7 | 0 | 24 |
| mcp-servers | 0 | 0 | 0 | 0 | 0 | 0 | 30 | 30 |
| **Total** | **22** | **27** | **47** | **4** | **10** | **16** | **30** | **159** |

---

## core@qazuor

### Agents (11)

| ID | Name | Description |
|----|------|-------------|
| A1 | tech-lead | Architectural oversight, code quality, security, deployment |
| A2 | product-functional | PDR creation, user stories, acceptance criteria |
| A3 | product-technical | Technical analysis, architecture design, implementation planning |
| A4 | qa-engineer | Test planning, quality gates, coverage tracking |
| A5 | debugger | Bug investigation, root cause analysis, Five Whys |
| A7 | content-writer | UX copywriting, brand voice, multilingual content |
| A8 | ux-ui-designer | UI design, user flows, WCAG accessibility |
| A10 | node-typescript-engineer | Node.js/TypeScript implementation, shared packages |
| A19 | code-reviewer | Systematic code review, pragmatic triage (Critical/Improvement/Nit) |
| A20 | devops-engineer | CI/CD, Docker, deployment, infrastructure |
| A22 | design-reviewer | Visual UI review with Playwright, 7-phase process |

### Commands (21)

| ID | Name | Description |
|----|------|-------------|
| C1 | /quality-check | Master validation: lint + test + review |
| C2 | /code-check | Linting and type checking |
| C3 | /run-tests | Test suite with coverage |
| C4 | /security-audit | OWASP security assessment |
| C5 | /performance-audit | Performance analysis |
| C6 | /accessibility-audit | WCAG 2.1 AA compliance |
| C15 | /add-new-entity | Scaffold new domain entity |
| C16 | /update-docs | Comprehensive documentation update |
| C17 | /five-why | Root cause analysis |
| C18 | /format-markdown | Markdown formatting and linting |
| C19 | /commit | Conventional commit message generation |
| C20 | /create-agent | Create new agent wizard |
| C21 | /create-command | Create new command wizard |
| C22 | /create-skill | Create new skill wizard |
| C23 | /help | Interactive help system |
| C30 | /code-review | Invoke code reviewer |
| C31 | /init-project | Initialize project configuration |
| C32 | /check-deps | Dependency audit |
| C33 | /generate-changelog | Changelog from git history |
| C35 | /security-review | Enhanced security review with confidence scoring |
| C36 | /design-review | Visual UI review |

### Skills (23)

| ID | Name | Description |
|----|------|-------------|
| S1 | tdd-methodology | TDD Red-Green-Refactor workflow |
| S2 | api-app-testing | API endpoint testing methodology |
| S3 | web-app-testing | Web application E2E testing |
| S4 | performance-testing | Performance testing methodology |
| S5 | security-testing | Security testing (OWASP Top 10) |
| S6 | qa-criteria-validator | Acceptance criteria validation |
| S8 | security-audit | Security audit patterns and checklists |
| S9 | performance-audit | Performance audit patterns |
| S10 | accessibility-audit | WCAG 2.1 AA audit patterns |
| S11 | error-handling-patterns | Error class hierarchies and recovery |
| S12 | git-commit-helper | Conventional commit message generation |
| S22 | markdown-formatter | Markdown formatting rules |
| S25 | json-data-auditor | JSON data validation and quality |
| S26 | mermaid-diagram-specialist | Mermaid diagram creation patterns |
| S36 | monorepo-patterns | Monorepo architecture patterns |
| S37 | zod-patterns | Zod validation patterns |
| S39 | ci-cd-patterns | CI/CD pipeline patterns |
| S40 | env-validation | Environment variable validation |
| S-tw | tech-writing | Documentation patterns (JSDoc, OpenAPI, ADR) |
| S-i18n | i18n-patterns | Internationalization patterns |
| S-seo | seo-patterns | SEO optimization patterns |
| S-fd | frontend-design | Pre-coding design process (Anthropic) |
| S-rp | react-performance | 40+ React performance rules (Vercel) |

### Docs (10)

| ID | Name | Description |
|----|------|-------------|
| D1 | code-standards | TypeScript coding standards |
| D2 | testing-standards | TDD workflow, coverage targets |
| D3 | architecture-patterns | Layer architecture, SOLID, DRY |
| D4 | atomic-commits | Conventional commits policy |
| D5 | documentation-standards | JSDoc, OpenAPI, ADR format |
| D6 | security-standards | OWASP Top 10, input validation |
| D7 | performance-standards | Core Web Vitals, query optimization |
| D9 | glossary | Plugin system terminology |
| D10 | quick-start | Getting started guide |
| D11 | api-design-standards | REST API design standards |

### Templates (9)

| ID | Name | Description |
|----|------|-------------|
| T1 | global.md.template | CLAUDE.md for global settings |
| T2 | project-generic.md.template | CLAUDE.md for projects |
| T6 | pdr-template.md | Product Design Requirements |
| T7 | tech-analysis-template.md | Technical analysis |
| T8 | todos-template.md | Task breakdown with progress |
| T11 | settings-template.json | Claude Code settings |
| T12 | brand-config.json.template | Brand configuration |
| T-cs | security-review.yml | GitHub Action for security review |
| T-cr | code-review.yml | GitHub Action for code review |

---

## notifications@qazuor

### Hooks (3)

| Name | Event | Description |
|------|-------|-------------|
| on-notification | Notification | Desktop notification + TTS audio |
| stop-beep | Stop | Main session completion beep |
| subagent-beep | SubagentStop | Subagent completion beep |

### Scripts (3)

| Name | Description |
|------|-------------|
| on-notification.sh | notify-send + piper TTS with OS detection |
| stop-beep.sh | 1000Hz sine wave (0.2s) |
| subagent-beep.sh | 800Hz sine wave (0.1s) |

---

## frameworks-frontend@qazuor

### Agents (4)

| ID | Name | Description |
|----|------|-------------|
| A12 | astro-engineer | Astro islands, SSG/SSR, Content Collections |
| A13 | react-senior-dev | React 19, hooks, Server Components |
| A15 | tanstack-start-engineer | TanStack Start full-stack framework |
| A23 | nextjs-engineer | Next.js App Router, SSR/SSG/ISR |

### Skills (11)

| ID | Name | Description |
|----|------|-------------|
| S15 | react-patterns | Components, hooks, compound patterns |
| S16 | zustand-patterns | Stores, slices, middleware, persist |
| S17 | react-hook-form-patterns | Forms + Zod, useFieldArray, Controller |
| S19 | tanstack-patterns | TanStack ecosystem overview |
| S20 | astro-patterns | Islands, routing, content collections |
| S21 | shadcn-specialist | Components, theming, cva variants |
| S28 | vercel-specialist | Deployment, edge functions, ISR |
| S42 | nextjs-patterns | App Router, Server Components, caching |
| S44 | tanstack-router-patterns | Type-safe routing, loaders, search params |
| S45 | tanstack-table-patterns | Columns, sorting, filtering, pagination |
| S46 | tanstack-query-patterns | Data fetching, cache, optimistic updates |

---

## frameworks-backend@qazuor

### Agents (4)

| ID | Name | Description |
|----|------|-------------|
| A14 | hono-engineer | Hono API routes, middleware, validation |
| A16 | db-drizzle-engineer | Drizzle ORM schemas, migrations, relations |
| A17 | nestjs-engineer | NestJS modules, DI, guards, pipes |
| A24 | prisma-engineer | Prisma schema, Client API, migrations |

### Skills (4)

| ID | Name | Description |
|----|------|-------------|
| S13 | hono-patterns | Middleware, routes, factory patterns |
| S14 | drizzle-patterns | Schema, relations, migrations, queries |
| S18 | nestjs-patterns | Modules, DI, guards, pipes, interceptors |
| S43 | prisma-patterns | Schema, Client, migrations, relations |

---

## frameworks-shared@qazuor

### Skills (2)

| ID | Name | Description |
|----|------|-------------|
| S38 | docker-patterns | Dockerfile, multi-stage, compose |
| S47 | github-actions-patterns | Workflows, jobs, caching, matrix builds |

---

## task-master@qazuor

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
| task-atomizer | Breaks features into atomic 1-3 hour tasks |
| task-from-spec | Orchestrates atomizer + scorer + grapher |
| spec-generator | Transforms plans into formal specs |

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

### MCP Servers (30)

| # | Server | Category | API Key |
|---|--------|----------|---------|
| 1 | sequential-thinking | Reasoning | No |
| 2 | context7 | Documentation | No |
| 3 | perplexity-ask | Web Search | Yes |
| 4 | filesystem | File Operations | No |
| 5 | git | Version Control | No |
| 6 | json | Data Processing | No |
| 7 | playwright | Browser Automation | No |
| 8 | chrome-devtools | Browser Debugging | No |
| 9 | docker | Containers | No |
| 10 | neon | PostgreSQL (Cloud) | Yes |
| 11 | postgres | PostgreSQL (Local) | Connection |
| 12 | sqlite | SQLite | Path |
| 13 | linear | Issue Tracking | Yes |
| 14 | github | GitHub Integration | Yes |
| 15 | vercel | Deployment | Yes |
| 16 | supabase | BaaS | Yes |
| 17 | @21st-dev/magic | Code Generation | Yes |
| 18 | shadcn-ui | Component Library | No |
| 19 | figma | Design | Yes |
| 20 | drizzle | ORM | No |
| 21 | mercadopago | Payments | Yes |
| 22 | sentry | Error Monitoring | Yes |
| 23 | socket | Dependency Security | Yes |
| 24 | cloudflare-docs | CDN Documentation | No |
| 25 | browserstack | Browser Testing | Yes |
| 26 | brave-search | Web Search | Yes |
| 27 | notion | Notes/Wiki | Yes |
| 28 | slack | Messaging | Yes |
| 29 | redis-upstash | Cache/Queue | Yes |
| 30 | prisma | ORM | No |
