# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-02-05

Major restructuring: separated knowledge components into external repository and reorganized plugins.

### Added

- **knowledge-sync@qazuor** (v2.0.0) .. Sync agents, skills, commands, docs, and templates from claude-code-knowledge repository
  - 1 command (/knowledge-sync with subcommands: setup, install, sync, remove, list, status)
  - SessionStart hook for automatic update checking
  - Auto-detection of project dependencies for smart component suggestions
- **permission-sync@qazuor** (v2.0.0) .. Extracted from core plugin
  - 2 commands (/sync-permissions, /show-permissions)
  - SessionStart hook for automatic permission sync
- **session-tools@qazuor** (v2.0.0) .. Extracted from core plugin
  - 2 commands (/diary, /reflect)
  - PreCompact hook for automatic diary entries
  - claude-mem watchdog script
- **claude-initializer@qazuor** (v2.0.0) .. Extracted from core plugin
  - 1 command (/init-project)
  - 4 templates (global.md, global-rules-block.md, settings, brand-config)
- **claude-code-knowledge** repository .. External knowledge base with 95 components
  - 20 agents, 43 skills, 17 commands, 11 docs, 4 templates
  - catalog.json with tags and dependency detectors

### Removed

- **core@qazuor** .. Redistributed into specialized plugins and knowledge repository
- **frameworks-frontend@qazuor** .. Moved to claude-code-knowledge repository
- **frameworks-backend@qazuor** .. Moved to claude-code-knowledge repository
- **frameworks-shared@qazuor** .. Moved to claude-code-knowledge repository
- **installer/** directory .. Replaced by plugin system and knowledge-sync

### Changed

- **notifications@qazuor** .. No changes, retained as-is
- **task-master@qazuor** .. No changes, retained as-is
- **mcp-servers@qazuor** .. No changes, retained as-is

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

[2.0.0]: https://github.com/qazuor/claude-code-plugins/releases/tag/v2.0.0
[1.0.0]: https://github.com/qazuor/claude-code-plugins/releases/tag/v1.0.0
