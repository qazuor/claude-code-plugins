# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-31

Initial public release of the Claude Code Plugins Marketplace.

### Added

#### Plugins (7)

- **core@qazuor** (v1.0.0) — Universal agents, commands, skills, docs, and templates
  - 11 agents (tech-lead, product-functional, product-technical, qa-engineer, debugger, content-writer, ux-ui-designer, node-typescript-engineer, code-reviewer, devops-engineer, design-reviewer)
  - 21 commands (/quality-check, /code-check, /run-tests, /security-audit, /commit, and more)
  - 23 skills (TDD, testing, security, patterns, documentation, SEO, i18n)
  - 11 docs (code standards, architecture, testing, security, API design, and more)
  - 6 templates (global CLAUDE.md, project CLAUDE.md, settings, brand config, CI/CD)
- **notifications@qazuor** (v1.0.0) — Desktop notifications, TTS audio, stop beeps
  - 3 hooks (Notification, Stop, SubagentStop)
  - 3 scripts with cross-platform OS detection
- **frameworks-frontend@qazuor** (v1.0.0) — Frontend framework expertise
  - 4 agents (react-senior-dev, nextjs-engineer, astro-engineer, tanstack-start-engineer)
  - 12 skills (React, Next.js, Astro, TanStack ecosystem, Shadcn, Zustand, Vercel)
- **frameworks-backend@qazuor** (v1.0.0) — Backend framework expertise
  - 4 agents (nestjs-engineer, hono-engineer, db-drizzle-engineer, prisma-engineer)
  - 4 skills (NestJS, Hono, Drizzle, Prisma patterns)
- **frameworks-shared@qazuor** (v1.0.0) — Shared infrastructure skills
  - 2 skills (docker-patterns, github-actions-patterns)
- **task-master@qazuor** (v1.0.0) — Planning, specs, task management, quality gates
  - 3 agents (spec-writer, tech-analyzer, task-planner)
  - 6 commands (/spec, /tasks, /next-task, /new-task, /task-status, /replan)
  - 7 skills (complexity-scorer, overlap-detector, dependency-grapher, quality-gate, task-atomizer, task-from-spec, spec-generator)
  - 7 templates (spec templates, JSON schemas, config)
  - Complexity ceiling of 4 with multi-pass progressive decomposition
- **mcp-servers@qazuor** (v1.0.0) — 30 pre-configured MCP server definitions

#### Installer

- Interactive installer with `--profile` support (full-stack, minimal, backend-only, frontend-only)
- User-level and project-level installation modes
- `--dry-run` flag for previewing changes without installing
- `--setup-mcp` for interactive API key configuration with masked input
- External plugin wizard for third-party plugin discovery
- Symlink-based architecture for instant updates via `git pull`
- Uninstaller and update scripts
- Installer integration test suite

#### CI/CD

- GitHub Actions workflow with JSON, ShellCheck, markdownlint validation
- Plugin structure validation (agents, commands, skills, hooks)
- Profile reference verification
- Installer integration tests

#### Documentation

- README.md with quick start, installation guides, plugin details
- CONTRIBUTING.md with SDD+TDD workflow and plugin creation guides
- PLUGIN-FORMAT.md with complete component format specification
- CATALOG.md with full component inventory (158 components)
- LICENSE (MIT)

[1.0.0]: https://github.com/qazuor/claude-code-plugins/releases/tag/v1.0.0
