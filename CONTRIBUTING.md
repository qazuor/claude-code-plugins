# Contributing

Thank you for contributing to the Claude Code Plugins Marketplace.

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
   ./installer/install.sh --enable my-plugin
   ```

## Adding Components to Existing Plugins

### New Agent

1. Create `plugins/<plugin>/agents/<name>.md`
2. Follow the agent format with YAML frontmatter
3. Include: name, description, tools, model, role, responsibilities

### New Command

1. Create `plugins/<plugin>/commands/<name>.md`
2. Follow the command format with purpose, process, options, output

### New Skill

1. Create `plugins/<plugin>/skills/<name>/SKILL.md`
2. Include: purpose, patterns with code examples, best practices

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
- Use `${CLAUDE_PLUGIN_ROOT}` for relative paths in scripts
- Skills use `SKILL.md` (uppercase) as the canonical filename
- Agent model should be `sonnet` unless there's a specific reason
- Include code examples in TypeScript where relevant
- Target 100-400 lines per component (enough detail without bloat)

## Pull Request Process

1. Create a feature branch
2. Add your components
3. Update CATALOG.md if adding new components
4. Test with the installer
5. Submit PR with description of changes
6. Ensure all CI checks pass (JSON validation, ShellCheck, markdownlint, plugin structure)
