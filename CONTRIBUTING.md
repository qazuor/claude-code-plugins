# Contributing

Thank you for contributing to the Claude Code Plugins Marketplace.

## Important: Where Do Components Go?

- **Plugins** (hooks, scripts, plugin-specific commands/templates) go in **this repository** under `plugins/`.
- **Knowledge components** (agents, skills, commands, docs, templates) go in the **[claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge)** repository, not here. The knowledge-sync plugin installs them into projects on demand.

## Development Workflow

This project follows **SDD + TDD** (Spec Driven Development + Test Driven Development).

### For Features and Large Changes

1. **Plan Mode** .. Enter Plan Mode, ask questions, clarify all requirements
2. **Spec** .. Use `/spec` to generate a detailed specification
3. **Tasks** .. Task-master generates atomic tasks from the spec
4. **Development** .. Use `/next-task` to work through tasks with TDD (Red-Green-Refactor)
5. **Quality Gate** .. Pass lint, typecheck, and tests before completing each task

### For Bug Fixes and Small Changes

1. Plan what needs to change
2. Make the change
3. Update README.md if plugin counts or descriptions change
4. Commit with a conventional commit message

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

3. Add components (commands, hooks, scripts, templates) following the format in [PLUGIN-FORMAT.md](PLUGIN-FORMAT.md).

4. Test by enabling the plugin in your Claude Code settings and verifying each component works as expected.

## Adding Components to Existing Plugins

### New Command

1. Create `plugins/<plugin>/commands/<name>.md`
2. Add YAML frontmatter with: `name`, `description`
3. Include: purpose, step-by-step process, options, output format

### New Hook

1. Create the hook entry in `plugins/<plugin>/.claude-plugin/plugin.json`
2. Add the corresponding script under `plugins/<plugin>/scripts/`
3. Include: trigger event, script path, platform detection if needed

### New Template

1. Create `plugins/<plugin>/templates/<name>.md`
2. Add YAML frontmatter with: `name`, `description`
3. Include: template content with placeholder variables

## Adding Knowledge Components

Agents, skills, commands, docs, and templates that provide reusable knowledge belong in the **[claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge)** repository. See that repository's CONTRIBUTING.md for details on:

- Creating a new agent
- Creating a new skill
- Creating a new command
- Adding docs or templates
- Updating catalog.json with tags and dependency detectors

## Agent vs Skill Decision

| Question | Agent | Skill |
|----------|-------|-------|
| Needs to think as a persona? | Yes | No |
| Makes domain decisions? | Yes | No |
| Has a workflow/methodology? | Yes | No |
| Is reference knowledge/patterns? | No | Yes |
| Invoked as "act as X"? | Yes | No |

## Guidelines

- Keep content **project-agnostic** .. no hardcoded project names, domains, or paths
- Use `${CLAUDE_PLUGIN_ROOT}` for plugin-relative paths in scripts
- Use `${CLAUDE_PROJECT_DIR}` for project-relative paths in scripts
- Skills use `SKILL.md` (uppercase) as the canonical filename
- Agent model should be `sonnet` unless there's a specific reason
- Include code examples in TypeScript where relevant
- Target 100-400 lines per component (enough detail without bloat)
- All naming follows **kebab-case** convention

## CI Checks

All submissions must pass the following CI checks:

- **JSON validation** .. All JSON files must be valid
- **ShellCheck** .. All shell scripts must pass linting
- **markdownlint** .. All markdown must follow formatting rules
- **Plugin structure** .. Plugin directories must have `.claude-plugin/plugin.json`
- **Skill format** .. Skills must have `SKILL.md` with YAML frontmatter
- **Agent format** .. Agents must have required frontmatter fields (`name`, `description`)
- **Command format** .. Commands must have YAML frontmatter

## Pull Request Process

1. Create a feature branch
2. Add your components
3. Update `README.md` if plugin counts or descriptions change
4. Submit PR with description of changes
5. Ensure all CI checks pass
