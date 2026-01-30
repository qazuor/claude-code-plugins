---
name: help
description: Interactive help system providing guidance on commands, agents, skills, and project structure
---

# Help Command

## Purpose

Provides comprehensive, context-aware help for the Claude Code workflow system. This command offers interactive assistance on commands, agents, skills, workflow phases, and project structure, helping developers quickly find the information they need.

## When to Use

- **Getting Started**: When first working with a project using Claude Code plugins
- **Command Discovery**: When looking for a specific command
- **Agent Information**: When wanting to know which agent to invoke
- **Workflow Guidance**: When unsure about workflow phases
- **Troubleshooting**: When encountering issues or errors

## Usage

```bash
/help [topic] [options]
```

### Topics

- `commands` - List and search commands
- `agents` - Browse agents by category
- `skills` - View available skills
- `workflow` - Understand workflow phases
- `quick-start` - Get started quickly
- `architecture` - Project structure overview
- `glossary` - Terminology and concepts

### Options

- `--search <query>`: Search across all documentation
- `--category <cat>`: Filter by category
- `--details`: Show detailed information
- `--examples`: Show usage examples

### Examples

```bash
/help                                    # Interactive help menu
/help commands                           # List all commands
/help commands --search test             # Search test-related commands
/help agents --category engineering      # Show engineering agents
/help workflow --details                 # Detailed workflow guide
/help quick-start                        # Quick start guide
```

## Help System Structure

### Main Help Menu

```
Project Help System
===================================================================

Welcome to the Claude Code workflow system!

Available Topics:

  1. commands     - Available slash commands
  2. agents       - Specialized AI agents
  3. skills       - Reusable workflows
  4. workflow     - Development workflow phases
  5. quick-start  - Getting started guide
  6. architecture - Project structure overview
  7. glossary     - Terminology and concepts

Search: /help --search <query>

Select topic (1-7) or press Enter for quick start:
```

### Commands Help

```
Available Commands
===================================================================

Development & Workflow
  /code-review          Systematic code review with severity reporting
  /check-deps           Check dependencies for updates and vulnerabilities
  /init-project         Initialize new project with Claude Code config

Planning & Project Management
  /generate-changelog   Generate changelog from git history

Quality & Validation
  /security-review      Enhanced security review with confidence scoring
  /design-review        Visual UI review via design-reviewer agent

Audit
  (Project-specific audit commands listed here)

Meta & System
  /create-agent         Create new specialized AI agent
  /create-command       Create new slash command
  /create-skill         Create new skill workflow
  /help                 Interactive help system (this command)

Use /help commands <name> for detailed information
Example: /help commands security-review
```

### Agents Help

```
Available Agents
===================================================================

(Lists all agents found in .claude/agents/ organized by category)

Product & Planning
  {agent-name}    {description}

Engineering
  {agent-name}    {description}

Quality
  {agent-name}    {description}

Design
  {agent-name}    {description}

Specialized
  {agent-name}    {description}

Use /help agents <name> for detailed information
Example: /help agents tech-lead
```

### Skills Help

```
Available Skills
===================================================================

(Lists all skills found in .claude/skills/ organized by category)

Testing
  {skill-name}         {description}

Development
  {skill-name}         {description}

Validation
  {skill-name}         {description}

Use /help skills <name> for detailed information
Example: /help skills qa-criteria-validator
```

### Workflow Help

```
Development Workflow
===================================================================

Phase 1: Planning
===================================================================

Goal: Create comprehensive, atomic plan

Steps:
1. Initialize planning session
2. Create Product Design Requirements (if applicable)
3. Create Technical Analysis
4. Break down into atomic tasks
5. Get user approval

Deliverables: Requirements documents, task breakdown

===================================================================

Phase 2: Implementation
===================================================================

Goal: Implement feature following best practices

Process:
1. Review planning documents
2. For each task:
   - Write tests first (TDD recommended)
   - Implement minimum code
   - Refactor while tests pass
3. Continuous verification:
   - /code-review
   - Run tests
4. Update task progress

===================================================================

Phase 3: Validation
===================================================================

Goal: Ensure quality standards

Steps:
1. Code review (/code-review)
2. Security review (/security-review)
3. Dependency check (/check-deps)
4. Design review (/design-review) - if applicable
5. User approval

===================================================================

Phase 4: Finalization
===================================================================

Goal: Document and prepare commits

Steps:
1. Update documentation
2. Generate changelog (/generate-changelog)
3. Create commits
4. Final checklist verification

Use /help workflow --details for comprehensive guide
```

## Detailed Help Output

### Command Details

When you run `/help commands <name>`, it shows detailed information:

```
Command: /security-review
===================================================================

Description:
Enhanced security review with confidence scoring (>= 0.8 threshold)
and exclusion list of 17 false positive categories.

When to Use:
- Before Production Deployment
- After Security-Related Changes
- Regular Security Reviews
- Post-Incident Analysis

Usage:
  /security-review [options]

Options:
  --scope <area>     Focus on specific area
  --confidence <n>   Minimum confidence threshold (default: 0.8)
  --report           Generate detailed report

Examples:
  /security-review
  /security-review --scope auth --confidence 0.9 --report

Related Commands:
- /code-review
- /check-deps

Documentation:
- .claude/commands/security-review.md
```

### Agent Details

When you run `/help agents <name>`, it shows detailed information:

```
Agent: code-reviewer
===================================================================

Category: Quality
Model: sonnet

Description:
Performs systematic code review analyzing correctness, security,
performance, and maintainability. Reports findings by severity level.

Primary Responsibilities:
1. Code quality analysis
2. Security vulnerability detection
3. Performance pattern review
4. Best practice validation

Tools: Read, Glob, Grep

Invocation Examples:
"Use the code-reviewer to review the authentication module"
"Invoke code-reviewer for final code quality review"

Documentation:
- .claude/agents/quality/code-reviewer.md
```

## Search Functionality

### Search Across All Documentation

```bash
/help --search "testing"
```

**Output:**

```
Search Results for "testing"
===================================================================

Commands (1)
  /code-review - Systematic code review (includes test coverage analysis)

Agents (1)
  qa-engineer - Testing and acceptance validation

Skills (1)
  api-integration-testing - API testing workflow

Documentation
  (Lists matching documentation files)

Use /help <type> <name> for details
```

## Quick Start

### Interactive Quick Start

```bash
/help quick-start
```

**Output:**

```
Quick Start Guide
===================================================================

Welcome! This guide gets you productive quickly.

Step 1: Understand the Structure
===================================================================

Key Files:
- CLAUDE.md - Main project guide
- .claude/agents/ - AI specialist agents
- .claude/commands/ - Available slash commands
- .claude/skills/ - Reusable workflows

Step 2: Basic Commands
===================================================================

Essential commands:
  /help              - This help system
  /help commands     - List all commands
  /code-review       - Review code quality
  /check-deps        - Check dependencies
  /security-review   - Security analysis

Try now:
  /help commands

Step 3: Understand Workflow
===================================================================

4 Phases:
1. Planning     - Create requirements and task breakdown
2. Implementation - Build with best practices
3. Validation   - Quality checks and reviews
4. Finalization - Documentation and commits

Next Steps:
===================================================================

- Read CLAUDE.md for comprehensive overview
- Explore .claude/docs/ for detailed guides
- Try running /code-review on your current changes
```

## Error Messages

When help topic not found:

```
Help Topic Not Found
===================================================================

Topic "xyz" not found.

Available topics:
- commands
- agents
- skills
- workflow
- quick-start
- architecture
- glossary

Try:
  /help                  - Main help menu
  /help --search xyz     - Search all documentation
```

## Integration with Workflow

The `/help` command is available at all times and integrates with:

- **Onboarding**: First command new developers should use
- **Discovery**: Finding the right command/agent for a task
- **Troubleshooting**: Understanding errors and issues
- **Learning**: Understanding workflow and patterns

## Best Practices

1. **Start with /help quick-start**: Get oriented quickly
2. **Use search**: /help --search is powerful for finding specific topics
3. **Explore categories**: Browse commands and agents by category
4. **Read details**: Use /help {type} {name} for comprehensive info
5. **Reference docs**: Help points to detailed documentation files

## Related Commands

- `/create-agent` - Create new agent
- `/create-command` - Create new command
- `/create-skill` - Create new skill

## Notes

- **Context-Aware**: Help adapts based on available agents, commands, and skills
- **Search**: Full-text search across all documentation
- **Examples**: Every help topic includes examples
- **Links**: Direct links to relevant documentation files
- **Interactive**: Guided navigation through help topics
- **Dynamic**: Auto-generated from actual agent/command/skill files found in the project
