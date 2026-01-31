# Plugin Catalog

Complete inventory of all components across all plugins.

## Summary

| Plugin | Agents | Commands | Skills | Hooks | Docs | Templates | MCP | Total |
|--------|--------|----------|--------|-------|------|-----------|-----|-------|
| core | 11 | 21 | 23 | 0 | 11 | 6 | 0 | 72 |
| notifications | 0 | 0 | 0 | 3 | 0 | 0 | 0 | 6 |
| frameworks-frontend | 4 | 0 | 11 | 0 | 0 | 0 | 0 | 15 |
| frameworks-backend | 4 | 0 | 4 | 0 | 0 | 0 | 0 | 8 |
| frameworks-shared | 0 | 0 | 2 | 0 | 0 | 0 | 0 | 2 |
| task-master | 3 | 6 | 7 | 1 | 0 | 7 | 0 | 24 |
| mcp-servers | 0 | 0 | 0 | 0 | 0 | 0 | 30 | 30 |
| **Total** | **22** | **27** | **47** | **4** | **11** | **13** | **30** | **157** |

---

## core@qazuor

### Agents (11)

| Name | Description |
|------|-------------|
| tech-lead | Architectural oversight, code quality, security, deployment |
| product-functional | PDR creation, user stories, acceptance criteria |
| product-technical | Technical analysis, architecture design, implementation planning |
| qa-engineer | Test planning, quality gates, coverage tracking |
| debugger | Bug investigation, root cause analysis, Five Whys |
| content-writer | UX copywriting, brand voice, multilingual content |
| ux-ui-designer | UI design, user flows, WCAG accessibility |
| node-typescript-engineer | Node.js/TypeScript implementation, shared packages |
| code-reviewer | Systematic code review, pragmatic triage (Critical/Improvement/Nit) |
| devops-engineer | CI/CD, Docker, deployment, infrastructure |
| design-reviewer | Visual UI review with Playwright, 7-phase process |

### Commands (21)

| Name | Description |
|------|-------------|
| /quality-check | Master validation: lint + test + review |
| /code-check | Linting and type checking |
| /run-tests | Test suite with coverage |
| /security-audit | OWASP security assessment |
| /performance-audit | Performance analysis |
| /accessibility-audit | WCAG 2.1 AA compliance |
| /add-new-entity | Scaffold new domain entity |
| /update-docs | Comprehensive documentation update |
| /five-why | Root cause analysis |
| /format-markdown | Markdown formatting and linting |
| /commit | Conventional commit message generation |
| /create-agent | Create new agent wizard |
| /create-command | Create new command wizard |
| /create-skill | Create new skill wizard |
| /help | Interactive help system |
| /code-review | Invoke code reviewer |
| /init-project | Initialize project configuration |
| /check-deps | Dependency audit |
| /generate-changelog | Changelog from git history |
| /security-review | Enhanced security review with confidence scoring |
| /design-review | Visual UI review |

### Skills (23)

| Name | Description |
|------|-------------|
| tdd-methodology | TDD Red-Green-Refactor workflow |
| api-app-testing | API endpoint testing methodology |
| web-app-testing | Web application E2E testing |
| performance-testing | Performance testing methodology |
| security-testing | Security testing (OWASP Top 10) |
| qa-criteria-validator | Acceptance criteria validation |
| security-audit | Security audit patterns and checklists |
| performance-audit | Performance audit patterns |
| accessibility-audit | WCAG 2.1 AA audit patterns |
| error-handling-patterns | Error class hierarchies and recovery |
| git-commit-helper | Conventional commit message generation |
| markdown-formatter | Markdown formatting rules |
| json-data-auditor | JSON data validation and quality |
| mermaid-diagram-specialist | Mermaid diagram creation patterns |
| monorepo-patterns | Monorepo architecture patterns |
| zod-patterns | Zod validation patterns |
| ci-cd-patterns | CI/CD pipeline patterns |
| env-validation | Environment variable validation |
| tech-writing | Documentation patterns (JSDoc, OpenAPI, ADR) |
| i18n-patterns | Internationalization patterns |
| seo-patterns | SEO optimization patterns |
| frontend-design | Pre-coding design process (Anthropic) |
| react-performance | 40+ React performance rules (Vercel) |

### Docs (11)

| Name | Description |
|------|-------------|
| api-design-standards | REST API design standards |
| architecture-patterns | Layer architecture, SOLID, DRY |
| atomic-commits | Conventional commits policy |
| code-standards | TypeScript coding standards |
| development-workflow | Full SDD+TDD development workflow |
| documentation-standards | JSDoc, OpenAPI, ADR format |
| glossary | Plugin system terminology |
| performance-standards | Core Web Vitals, query optimization |
| quick-start | Getting started guide |
| security-standards | OWASP Top 10, input validation |
| testing-standards | TDD workflow, coverage targets |

### Templates (6)

| Name | Description |
|------|-------------|
| global.md.template | CLAUDE.md for global settings |
| project-generic.md.template | CLAUDE.md for projects |
| settings-template.json | Claude Code settings |
| brand-config.json.template | Brand configuration |
| security-review.yml | GitHub Action for security review |
| code-review.yml | GitHub Action for code review |

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

| Name | Description |
|------|-------------|
| astro-engineer | Astro islands, SSG/SSR, Content Collections |
| react-senior-dev | React 19, hooks, Server Components |
| tanstack-start-engineer | TanStack Start full-stack framework |
| nextjs-engineer | Next.js App Router, SSR/SSG/ISR |

### Skills (12)

| Name | Description |
|------|-------------|
| react-patterns | Components, hooks, compound patterns |
| vercel-react-best-practices | 57 React/Next.js performance rules from Vercel Engineering |
| zustand-patterns | Stores, slices, middleware, persist |
| react-hook-form-patterns | Forms + Zod, useFieldArray, Controller |
| tanstack-patterns | TanStack ecosystem overview |
| astro-patterns | Islands, routing, content collections |
| shadcn-specialist | Components, theming, cva variants |
| vercel-specialist | Deployment, edge functions, ISR |
| nextjs-patterns | App Router, Server Components, caching |
| tanstack-router-patterns | Type-safe routing, loaders, search params |
| tanstack-table-patterns | Columns, sorting, filtering, pagination |
| tanstack-query-patterns | Data fetching, cache, optimistic updates |

---

## frameworks-backend@qazuor

### Agents (4)

| Name | Description |
|------|-------------|
| hono-engineer | Hono API routes, middleware, validation |
| db-drizzle-engineer | Drizzle ORM schemas, migrations, relations |
| nestjs-engineer | NestJS modules, DI, guards, pipes |
| prisma-engineer | Prisma schema, Client API, migrations |

### Skills (4)

| Name | Description |
|------|-------------|
| hono-patterns | Middleware, routes, factory patterns |
| drizzle-patterns | Schema, relations, migrations, queries |
| nestjs-patterns | Modules, DI, guards, pipes, interceptors |
| prisma-patterns | Schema, Client, migrations, relations |

---

## frameworks-shared@qazuor

### Skills (2)

| Name | Description |
|------|-------------|
| docker-patterns | Dockerfile, multi-stage, compose |
| github-actions-patterns | Workflows, jobs, caching, matrix builds |

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
| task-atomizer | Breaks features into atomic sub-tasks |
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
