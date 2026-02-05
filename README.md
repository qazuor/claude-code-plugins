# Claude Code Plugins

[![CI](https://github.com/qazuor/claude-code-plugins/actions/workflows/ci.yml/badge.svg)](https://github.com/qazuor/claude-code-plugins/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Plugins](https://img.shields.io/badge/Plugins-7-green.svg)](#plugins)

A curated collection of plugins for [Claude Code](https://claude.ai/claude-code) .. Anthropic's official CLI tool. Knowledge components (agents, skills, commands, docs, templates) live in a separate repository ([claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge)) and are managed by the **knowledge-sync** plugin.

## Quick Start

```bash
git clone https://github.com/qazuor/claude-code-plugins.git
```

Install individual plugins via the Claude Code plugin system:

```bash
# From within Claude Code, add the plugins you need
claude plugin add /path/to/claude-code-plugins/plugins/knowledge-sync
claude plugin add /path/to/claude-code-plugins/plugins/notifications
claude plugin add /path/to/claude-code-plugins/plugins/task-master
# ... and so on for each plugin you want
```

### Update

```bash
cd claude-code-plugins && git pull
# Symlinks mean updates are instant .. no reinstall needed
```

## Plugins

| Plugin | Description | Includes |
|--------|-------------|----------|
| **knowledge-sync** | Sync agents, skills, commands, docs and templates from claude-code-knowledge repo | 1 command, 1 hook, 3 scripts, 2 templates |
| **permission-sync** | Auto-learn and sync Claude Code permissions across projects | 2 commands, 1 hook, 2 scripts, 1 template |
| **session-tools** | Session diary entries, reflections, and claude-mem watchdog | 2 commands, 1 hook, 2 scripts |
| **claude-initializer** | Project initialization with CLAUDE.md generation and merge | 1 command, 4 templates |
| **notifications** | Desktop notifications, TTS audio, stop beeps | 3 hooks, 3 scripts |
| **task-master** | Planning, specs, task management, quality gates | 3 agents, 6 commands, 1 hook, 1 script, 7 skills, 7 templates |
| **mcp-servers** | 30 pre-configured MCP server definitions | 30 MCP servers |

## Knowledge Repository

Agents, skills, commands, docs and templates live in a dedicated repository:

**[claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge)** .. 95 components total:

| Type | Count |
|------|-------|
| Agents | 20 |
| Skills | 43 |
| Commands | 17 |
| Docs | 11 |
| Templates | 4 |

The **knowledge-sync** plugin manages these components automatically. It detects project dependencies (package.json, config files) and syncs only the relevant agents, skills, commands, docs and templates into your project. No manual configuration needed.

## Architecture

```
claude-code-plugins/
  plugins/
    knowledge-sync/        # Knowledge management
    permission-sync/       # Permission synchronization
    session-tools/         # Session diary and reflections
    claude-initializer/    # Project initialization
    notifications/         # Desktop and audio alerts
    task-master/           # Planning and task management
    mcp-servers/           # MCP server configurations
  README.md
  CATALOG.md
  CHANGELOG.md
  CONTRIBUTING.md
  PLUGIN-FORMAT.md
  SECURITY.md
  package.json
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to create new plugins.

See [PLUGIN-FORMAT.md](PLUGIN-FORMAT.md) for the plugin format specification.

## License

MIT
