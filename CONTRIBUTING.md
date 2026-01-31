# Contributing

Thank you for contributing to the Claude Code Plugins Marketplace.

## Development Workflow

This project follows **SDD + TDD** (Spec Driven Development + Test Driven Development). See [development-workflow.md](plugins/core/docs/development-workflow.md) for the full process.

### For Features and Large Changes

1. **Plan Mode** — Enter Plan Mode, ask questions, clarify all requirements
2. **Spec** — Use `/spec` to generate a detailed specification
3. **Tasks** — Task-master generates atomic tasks from the spec
4. **Development** — Use `/next-task` to work through tasks with TDD (Red-Green-Refactor)
5. **Quality Gate** — Pass lint, typecheck, and tests before completing each task

### For Bug Fixes and Small Changes

1. Plan what needs to change
2. Make the change
3. Verify with `--dry-run` if touching the installer
4. Update CATALOG.md if component counts change
5. Commit with a conventional commit message

## Creating a New Plugin

1. Create a directory under `plugins/`:
   ```
   plugins/my-plugin/
   ```

2. Add the manifest:
   ```json
   // plugins/my-plugin/.claude-plugin/plugin.json
   {
     "name": "my-plugin",
     "version": "1.0.0",
     "description": "What this plugin does",
     "author": { "name": "Your Name" },
     "license": "MIT"
   }
   ```

3. Add components (agents, commands, skills, etc.) following the format in [PLUGIN-FORMAT.md](PLUGIN-FORMAT.md).

4. Test by running the installer:
   ```bash
   ./installer/install.sh --enable my-plugin --dry-run  # preview first
   ./installer/install.sh --enable my-plugin             # then install
   ```

## Adding Components to Existing Plugins

### New Agent

1. Create `plugins/<plugin>/agents/<name>.md`
2. Add YAML frontmatter with required fields: `name`, `description`
3. Recommended fields: `tools`, `model`
4. Include: role definition, responsibilities, working context

### New Command

1. Create `plugins/<plugin>/commands/<name>.md`
2. Add YAML frontmatter with: `name`, `description`
3. Include: purpose, step-by-step process, options, output format

### New Skill

1. Create `plugins/<plugin>/skills/<name>/SKILL.md`
2. Add YAML frontmatter with: `description`
3. Include: purpose, patterns with code examples, best practices

## Agent vs Skill Decision

| Question | Agent | Skill |
|----------|-------|-------|
| Needs to think as a persona? | Yes | No |
| Makes domain decisions? | Yes | No |
| Has a workflow/methodology? | Yes | No |
| Is reference knowledge/patterns? | No | Yes |
| Invoked as "act as X"? | Yes | No |

## Guidelines

- Keep content **project-agnostic** — no hardcoded project names, domains, or paths
- Use `${CLAUDE_PLUGIN_ROOT}` for plugin-relative paths in scripts
- Use `${CLAUDE_PROJECT_DIR}` for project-relative paths in scripts
- Skills use `SKILL.md` (uppercase) as the canonical filename
- Agent model should be `sonnet` unless there's a specific reason
- Include code examples in TypeScript where relevant
- Target 100-400 lines per component (enough detail without bloat)
- All naming follows **kebab-case** convention

## CI Checks

All submissions must pass the following CI checks:

- **JSON validation** — All JSON files must be valid
- **ShellCheck** — All shell scripts must pass linting
- **markdownlint** — All markdown must follow formatting rules
- **Plugin structure** — Plugin directories must have `.claude-plugin/plugin.json`
- **Skill format** — Skills must have `SKILL.md` with YAML frontmatter
- **Agent format** — Agents must have required frontmatter fields (`name`, `description`)
- **Command format** — Commands must have YAML frontmatter
- **Profile verification** — Profiles must reference existing plugins
- **Installer tests** — Installer scripts must pass unit and integration tests

## Pull Request Process

1. Create a feature branch
2. Add your components
3. Update `CATALOG.md` if adding, removing, or renaming components
4. Update `README.md` if component counts change
5. Test with the installer (`--dry-run` first)
6. Submit PR with description of changes
7. Ensure all CI checks pass
