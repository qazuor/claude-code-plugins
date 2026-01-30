# Quick Start Guide

Get up and running with the Claude Code plugin system in 15 minutes.

---

## Prerequisites

Before starting, ensure you have:

- [x] Claude Code CLI installed
- [x] Your project repository cloned
- [x] Node.js >= 18 installed
- [x] A package manager (npm, pnpm, or yarn)

---

## Step 1: Understand the Structure

### Plugin Directory Layout

```
.claude/
  plugins/
    core/                   # Core plugin (always included)
      agents/               # Specialized AI assistants
      commands/             # Slash commands
      skills/               # Reusable capabilities
      docs/                 # Standards and guides
      templates/            # Document and config templates
    {tech-stack}/           # Tech-specific plugins (e.g., astro, react)
      agents/
      commands/
      skills/
      docs/
```

### Key Concepts

| Term | Definition | Example |
|------|-----------|---------|
| **Agent** | Specialized AI assistant | `qa-engineer`, `db-engineer` |
| **Command** | Slash-invokable workflow | `/quality-check`, `/commit` |
| **Skill** | Reusable capability | `git-commit-helper`, `tdd-workflow` |
| **Template** | Starting point for new docs | `pdr-template.md`, `settings-template.json` |

**Learn more:** See [glossary.md](glossary.md) for comprehensive terminology.

---

## Step 2: Choose Your Workflow Level

The system supports 3 workflow levels based on task complexity:

### Level 1: Quick Fix (< 30 minutes)

**Use for:** Typo fixes, formatting, import organization, config tweaks

**Process:** Edit -> Quick Validation -> Commit

### Level 2: Atomic Task (30 min - 3 hours)

**Use for:** Bug fixes, small features, targeted refactoring

**Process:** Simplified Planning -> TDD Implementation -> Quality Check -> Commit

### Level 3: Full Feature (> 3 hours)

**Use for:** Complete features, database changes, API changes, architecture changes

**Process:** 4-phase workflow (Planning -> Implementation -> Validation -> Finalization)

---

## Step 3: Start Your First Task

### For Quick Fixes (Level 1)

1. Make the change
2. Run tests: `npm test`
3. Commit with conventional format: `fix(scope): description`

### For Standard Tasks (Level 2)

1. **Plan:** Define what you need to build
2. **Test first:** Write a failing test
3. **Implement:** Write code to pass the test
4. **Refactor:** Clean up while tests stay green
5. **Validate:** Run quality checks
6. **Commit:** Stage specific files and commit

### For Features (Level 3)

1. **Phase 1 - Planning:**
   - Create PDR (Product Design Requirements)
   - Create Technical Analysis
   - Break down into atomic tasks

2. **Phase 2 - Implementation:**
   - Follow TDD for each task
   - Commit after each task
   - Update progress

3. **Phase 3 - Validation:**
   - Run quality checks (lint, typecheck, tests)
   - Security review
   - Performance review

4. **Phase 4 - Finalization:**
   - Update documentation
   - Generate conventional commits
   - Create PR

---

## Step 4: Use Templates

Templates are available in the `templates/` directory:

| Template | Purpose |
|----------|---------|
| `global.md.template` | Universal CLAUDE.md rules |
| `project-generic.md.template` | Project-specific CLAUDE.md |
| `pdr-template.md` | Product Design Requirements |
| `tech-analysis-template.md` | Technical Analysis |
| `todos-template.md` | Task Breakdown |
| `settings-template.json` | Claude Code settings |

### Using a Template

1. Copy the template to your project
2. Replace all `{{PLACEHOLDER}}` markers with your values
3. Remove any sections that do not apply

---

## Common Commands Reference

### During Development

| Task | Action |
|------|--------|
| Run tests | `npm test` |
| Type check | `npx tsc --noEmit` |
| Lint code | `npx biome check .` |
| Format code | `npx biome check --apply .` |

### Git Operations

| Task | Action |
|------|--------|
| Check status | `git status` |
| Stage specific files | `git add <file>` |
| Commit | `git commit -m "type(scope): description"` |
| View changes | `git diff` |

---

## Best Practices

### DO

- Follow TDD (test first, code second)
- Keep tasks atomic (0.5-4 hours)
- Write all code and comments in English
- Run quality checks before finalizing
- Commit incrementally per task
- Use schema validation for all inputs

### DON'T

- Skip writing tests
- Create tasks longer than 4 hours (break them down)
- Use `any` type (use `unknown` with type guards)
- Use `git add .` (stage files individually)
- Commit without running tests

---

## Getting Help

### Documentation

- **This guide:** Quick overview and common tasks
- **[glossary.md](glossary.md):** Terminology reference
- **[code-standards.md](code-standards.md):** Coding standards
- **[testing-standards.md](testing-standards.md):** Testing practices
- **[architecture-patterns.md](architecture-patterns.md):** Architecture guide
- **[atomic-commits.md](atomic-commits.md):** Git commit policy

### Agent Assistance

Ask Claude to invoke specialized agents:

```
"Use the qa-engineer agent to validate my test coverage"
"Invoke the db-engineer agent to help design my schema"
"Call the tech-lead agent to review my architecture"
```

---

## Next Steps

1. **Read the standards:** Review docs in `plugins/core/docs/`
2. **Set up templates:** Copy relevant templates to your project
3. **Configure settings:** Use `settings-template.json` as a starting point
4. **Start coding:** Pick a task and follow the appropriate workflow level
