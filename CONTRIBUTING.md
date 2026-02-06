# Contributing

Thank you for contributing to the Claude Code Plugins Marketplace.

## Table of Contents

- [Important: Where Do Components Go?](#important-where-do-components-go)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Creating a New Plugin](#creating-a-new-plugin)
- [Adding Components to Existing Plugins](#adding-components-to-existing-plugins)
- [Testing Your Changes](#testing-your-changes)
- [CI Checks](#ci-checks)
- [Pull Request Process](#pull-request-process)
- [Guidelines](#guidelines)

---

## Important: Where Do Components Go?

| Component Type | Location | Example |
|----------------|----------|---------|
| **Plugins** (hooks, scripts, plugin-specific commands) | This repository (`plugins/`) | notifications, task-master |
| **Knowledge components** (agents, skills, commands, docs, templates) | [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) | react-patterns, tech-lead agent |

If you're adding reusable knowledge (patterns, methodologies, specialized agents), contribute to the knowledge repository instead.

---

## Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/qazuor/claude-code-plugins.git
cd claude-code-plugins
```

### 2. Install Dependencies (for testing)

```bash
# jq is required for JSON manipulation in tests
sudo apt install jq  # Debian/Ubuntu
brew install jq      # macOS
```

### 3. Run Tests Locally

```bash
# Run all tests
bash tests/run-all.sh

# Run specific test file
bash tests/test-structure.sh
```

### 4. Test Plugin Installation

Option A: Add marketplace in Claude Code:
```
/plugin → Add marketplace → /path/to/claude-code-plugins
```

Option B: Install from GitHub marketplace:
```
/plugin → Add marketplace → qazuor/claude-code-plugins
```

---

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
2. Write or update tests if applicable
3. Make the change
4. Run tests locally (`bash tests/run-all.sh`)
5. Update documentation if needed
6. Commit with a conventional commit message

---

## Creating a New Plugin

### 1. Create Directory Structure

```
plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Required: Plugin manifest
├── commands/                 # Optional: Slash commands
├── hooks/
│   └── hooks.json           # Optional: Event hooks
├── scripts/                  # Optional: Shell scripts for hooks
└── templates/                # Optional: Template files
```

### 2. Create the Manifest

`.claude-plugin/plugin.json`:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "What this plugin does in one sentence",
  "author": {
    "name": "Your Name",
    "url": "https://github.com/yourusername"
  },
  "license": "MIT"
}
```

**Important:** The `name` field MUST match the directory name.

### 3. Add Components

Follow the formats in [PLUGIN-FORMAT.md](PLUGIN-FORMAT.md) for:
- Commands (markdown with YAML frontmatter)
- Hooks (JSON configuration)
- Scripts (bash with proper error handling)
- Templates (any format appropriate for the use case)

### 4. Update Marketplace

Add your plugin to `.claude-plugin/marketplace.json`:

```json
{
  "plugins": [
    ...existing plugins...,
    {
      "name": "my-plugin",
      "description": "What this plugin does",
      "source": "./plugins/my-plugin"
    }
  ]
}
```

### 5. Add Tests

Create `tests/test-my-plugin.sh` following the pattern of existing test files.

---

## Adding Components to Existing Plugins

### New Command

1. Create `plugins/<plugin>/commands/<name>.md`
2. Add YAML frontmatter:
   ```yaml
   ---
   name: command-name
   description: What this command does
   ---
   ```
3. Document: purpose, process steps, options, output format

### New Hook

1. Add entry to `plugins/<plugin>/hooks/hooks.json`:
   ```json
   {
     "hooks": {
       "EventName": [{
         "hooks": [{
           "type": "command",
           "command": "${CLAUDE_PLUGIN_ROOT}/scripts/my-script.sh",
           "timeout": 10
         }]
       }]
     }
   }
   ```
2. Create the script under `plugins/<plugin>/scripts/`
3. Make script executable: `chmod +x scripts/my-script.sh`

### New Template

1. Create `plugins/<plugin>/templates/<name>.<ext>`
2. Use appropriate format (.md, .json, .yml, etc.)
3. Include placeholders with clear naming: `${PROJECT_NAME}`, `${AUTHOR}`, etc.

---

## Testing Your Changes

### Run All Tests

```bash
bash tests/run-all.sh
```

### Run Specific Test Suite

```bash
bash tests/test-structure.sh    # JSON, manifests, naming
bash tests/test-hooks.sh        # Hook configuration
bash tests/test-<plugin>.sh     # Plugin-specific tests
```

### Manual Testing

1. Install your plugin locally via `/plugin`
2. Test each component:
   - Commands: Run the slash command
   - Hooks: Trigger the event (e.g., start new session for SessionStart)
   - Scripts: Run directly with test inputs

### ShellCheck

```bash
# Check all scripts
shellcheck plugins/*/scripts/*.sh

# Check with same settings as CI
shellcheck -x --severity=warning plugins/*/scripts/*.sh
```

---

## CI Checks

All submissions must pass these automated checks:

| Check | What it validates |
|-------|-------------------|
| **JSON validation** | All JSON files are syntactically valid |
| **ShellCheck** | Shell scripts pass linting (warnings and errors) |
| **markdownlint** | Markdown follows formatting rules |
| **Plugin structure** | Each plugin has `.claude-plugin/plugin.json` |
| **Plugin names** | Manifest name matches directory name |
| **Skill format** | Skills have `SKILL.md` with YAML frontmatter |
| **Agent format** | Agents have required frontmatter (`name`, `description`) |
| **Command format** | Commands have YAML frontmatter |
| **Test suite** | All 632+ tests pass |

---

## Pull Request Process

### Before Submitting

1. Run tests locally: `bash tests/run-all.sh`
2. Run ShellCheck on any new/modified scripts
3. Update documentation if plugin counts or descriptions change
4. Update CHANGELOG.md with your changes under `[Unreleased]`

### PR Description

Include:
- **What** .. Brief description of the change
- **Why** .. Motivation or issue being fixed
- **How** .. High-level approach
- **Testing** .. How you verified it works

### Review Process

1. CI checks must pass
2. Maintainer reviews code and documentation
3. Address any feedback
4. Squash and merge

---

## Guidelines

### Code Style

- **Shell scripts**: Follow ShellCheck recommendations
- **JSON**: Use 2-space indentation
- **Markdown**: Follow markdownlint rules (see `.markdownlint.json`)

### Naming Conventions

| Component | Convention | Example |
|-----------|------------|---------|
| Plugin directory | kebab-case | `my-plugin/` |
| Command file | kebab-case.md | `my-command.md` |
| Skill directory | kebab-case/ | `my-skill/` |
| Skill file | SKILL.md (uppercase) | `SKILL.md` |
| Script file | kebab-case.sh | `my-script.sh` |
| Hook event | PascalCase | `SessionStart` |

### Content Guidelines

- Keep content **project-agnostic** .. no hardcoded project names, domains, or paths
- Use variables for paths:
  - `${CLAUDE_PLUGIN_ROOT}` .. Plugin directory
  - `${CLAUDE_PROJECT_DIR}` .. Project root directory
- Target 100-400 lines per component (enough detail without bloat)
- Include code examples in TypeScript where relevant
- Agent model should be `sonnet` unless there's a specific reason for `opus` or `haiku`

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

feat(task-master): add dependency visualization command
fix(notifications): handle missing audio device gracefully
docs(readme): update installation instructions
test(hooks): add tests for PreCompact event
chore(ci): update ShellCheck to latest version
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

---

## Questions?

- Open an issue for bugs or feature requests
- Check existing issues before creating new ones
- For knowledge components, contribute to [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) instead
