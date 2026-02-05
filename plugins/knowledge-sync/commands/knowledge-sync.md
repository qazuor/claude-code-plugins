---
description: Manage knowledge components (agents, skills, commands, docs, templates) from claude-code-knowledge repository
---

# Knowledge Sync Command

Synchronize agents, skills, commands, docs, and templates from the [claude-code-knowledge](https://github.com/qazuor/claude-code-knowledge) repository to your projects.

## Usage

```
/knowledge-sync <subcommand> [options]
```

## Subcommands

### setup

Clone the knowledge repository and initialize configuration.

```
/knowledge-sync setup [--repo <url>]
```

**What it does:**

1. Creates `~/.claude/knowledge-sync/` directory
2. Clones the knowledge repository to `~/.claude/knowledge-sync/cache/`
3. Creates `~/.claude/knowledge-sync/config.json` with repository URL and cache path
4. Creates `~/.claude/knowledge-sync/registry.json` with empty projects map

**Actions:**

```bash
# Create directories
mkdir -p ~/.claude/knowledge-sync/cache

# Clone the repository
REPO_URL="${1:-https://github.com/qazuor/claude-code-knowledge.git}"
git clone "$REPO_URL" ~/.claude/knowledge-sync/cache

# Read the catalog
cat ~/.claude/knowledge-sync/cache/catalog.json
```

Then create config.json:
```json
{
  "repoUrl": "<repo-url>",
  "cachePath": "~/.claude/knowledge-sync/cache",
  "lastPull": "<current-iso-timestamp>"
}
```

And registry.json:
```json
{
  "projects": {}
}
```

Write both files to `~/.claude/knowledge-sync/`.

---

### install --detect

Analyze the current project and suggest components to install based on package.json dependencies.

```
/knowledge-sync install --detect
```

**What it does:**

1. Read `package.json` (or `pyproject.toml`, `Cargo.toml`) from the current project
2. Read `~/.claude/knowledge-sync/cache/catalog.json`
3. Match project dependencies against component `detectors`
4. Also suggest all `full-stack` tagged components (universal)
5. Present the suggested list to the user
6. Let the user edit the list (add/remove items)
7. Copy selected components to the project's `.claude/` directory
8. Update `~/.claude/knowledge-sync/registry.json`

**Detection logic:**

```bash
# Read package.json dependencies
cat package.json | jq -r '(.dependencies // {} | keys[]) + "\n" + (.devDependencies // {} | keys[])' 2>/dev/null | sort -u
```

For each component in catalog.json, check if any of its `detectors` match the dependency list. Group matches by type (agent, skill, command, doc, template).

**Component installation:**

For each selected component, copy from cache to project:
- Agents: `~/.claude/knowledge-sync/cache/agents/<name>.md` -> `.claude/agents/<name>.md`
- Skills: `~/.claude/knowledge-sync/cache/skills/<name>/SKILL.md` -> `.claude/skills/<name>/SKILL.md`
- Commands: `~/.claude/knowledge-sync/cache/commands/<name>.md` -> `.claude/commands/<name>.md`
- Docs: `~/.claude/knowledge-sync/cache/docs/<name>.md` -> `.claude/docs/<name>.md`
- Templates: `~/.claude/knowledge-sync/cache/templates/<name>` -> `.claude/templates/<name>`

Create target directories as needed with `mkdir -p`.

**Registry update:**

Add the current project to `~/.claude/knowledge-sync/registry.json`:
```json
{
  "projects": {
    "/path/to/current/project": {
      "agents": ["react-senior-dev", "code-reviewer"],
      "skills": ["react-patterns", "tdd-methodology"],
      "commands": ["commit", "code-review"],
      "docs": [],
      "templates": [],
      "syncedAt": "<current-iso-timestamp>",
      "syncedCommit": "<HEAD-sha-from-cache>"
    }
  }
}
```

---

### install --component \<name\>

Install a specific component by name.

```
/knowledge-sync install --component react-patterns
/knowledge-sync install --component code-reviewer
```

**What it does:**

1. Look up the component in `~/.claude/knowledge-sync/cache/catalog.json`
2. Copy the component file(s) to `.claude/` in the current project
3. Update the registry

---

### install --tag \<tag\>

Install all components matching a tag.

```
/knowledge-sync install --tag frontend
/knowledge-sync install --tag testing
```

**What it does:**

1. Filter catalog.json components by the specified tag
2. Present the filtered list to the user for confirmation
3. Copy selected components to `.claude/`
4. Update the registry

---

### sync

Update installed components to the latest version from the repository.

```
/knowledge-sync sync
```

**What it does:**

1. Run `git pull` in `~/.claude/knowledge-sync/cache/`
2. Read the current project's entry from the registry
3. For each installed component, compare cache version with installed version
4. Copy updated files to the project's `.claude/` directory
5. Update `syncedAt` and `syncedCommit` in the registry

```bash
cd ~/.claude/knowledge-sync/cache && git pull --ff-only
```

---

### sync --all

Update components across all registered projects.

```
/knowledge-sync sync --all
```

**What it does:**

1. Run `git pull` in cache
2. For each project in the registry, sync its installed components
3. Report what was updated per project

---

### remove \<name\>

Remove a component from the current project.

```
/knowledge-sync remove react-patterns
```

**What it does:**

1. Look up the component in the registry for the current project
2. Delete the file(s) from `.claude/`
3. Update the registry

---

### remove --all

Remove all knowledge components from the current project.

```
/knowledge-sync remove --all
```

**What it does:**

1. Read all components from the registry for the current project
2. Delete all installed component files from `.claude/`
3. Remove the project entry from the registry

---

### list

Show the complete knowledge catalog.

```
/knowledge-sync list [--tag <tag>] [--type <type>]
```

**What it does:**

1. Read `~/.claude/knowledge-sync/cache/catalog.json`
2. Read the current project's registry entry
3. Display all components grouped by type
4. Mark installed components with a checkmark

**Output format:**

```
=== KNOWLEDGE CATALOG ===

Agents (20):
  [x] code-reviewer        [full-stack, quality]
  [ ] content-writer        [full-stack, docs]
  [x] react-senior-dev      [frontend]         (detects: react, react-dom)
  ...

Skills (43):
  [x] react-patterns        [frontend]         (detects: react, react-dom)
  [ ] nestjs-patterns        [backend, api]     (detects: @nestjs/core)
  ...

Commands (17):
  [x] commit                 [full-stack]
  [ ] security-audit         [full-stack, security]
  ...

Docs (11):
  [ ] code-standards         [full-stack]
  ...

Templates (4):
  [ ] brand-config           [frontend, design]
  ...

Installed: X/95 components
```

---

### status

Show what knowledge components are installed in the current project.

```
/knowledge-sync status
```

**What it does:**

1. Read the current project's entry from the registry
2. Display installed components grouped by type
3. Show sync timestamp and commit

**Output format:**

```
=== KNOWLEDGE STATUS ===

Project: /path/to/project
Synced at: 2026-02-05T03:00:00Z
Synced commit: a1b2c3d

Agents (2):
  - code-reviewer
  - react-senior-dev

Skills (3):
  - react-patterns
  - tdd-methodology
  - zod-patterns

Commands (2):
  - commit
  - code-review

Total: 7 components
```

---

### status --all

Show status for all registered projects.

```
/knowledge-sync status --all
```

---

## Important Notes

- The knowledge repository is cached locally at `~/.claude/knowledge-sync/cache/`
- Components are copied (not symlinked) to ensure they work independently
- The registry tracks what each project has installed for update purposes
- Run `setup` once before using any other subcommand
- The SessionStart hook automatically checks for updates silently

$ARGUMENTS

Parse the subcommand and options from `$ARGUMENTS` and execute the appropriate action described above. Use bash commands for file operations and git commands. Use jq for JSON processing. Present results clearly to the user.
