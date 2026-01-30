---
name: create-agent
description: Interactive wizard to create a new specialized AI agent following best practices and project standards
---

# Create Agent Command

## Purpose

Guides you through creating a new specialized AI agent. This interactive wizard ensures the agent follows all standards, integrates properly with the workflow system, and includes comprehensive documentation. The wizard walks through 5 steps: Discovery, File Generation, Integration, Validation, and Commit.

## When to Use

- **New Specialized Role Needed**: When a specific expertise area requires dedicated attention
- **Responsibility Gaps**: When existing agents don't cover a needed capability
- **Separation of Concerns**: When an agent's responsibilities become too broad
- **Team Expansion**: When scaling development requires additional specialists

## Usage

```bash
/create-agent [options]
```

### Options

- `--name <kebab-case>`: Agent name (e.g., `graphql-engineer`)
- `--category <category>`: Category (product, engineering, quality, design, specialized)
- `--interactive`: Full interactive mode (default)
- `--template <type>`: Use template (technical, product, quality, design)

### Examples

```bash
/create-agent                                    # Interactive mode
/create-agent --name graphql-engineer --category engineering
/create-agent --template technical --interactive
```

## Agent Creation Process

### Step 1: Agent Discovery & Planning

**Questions Asked:**

1. **Agent Name** (kebab-case):
   - Examples: `graphql-engineer`, `seo-specialist`, `data-analyst`
   - Must be unique, descriptive, and follow naming conventions
   - Validation: lowercase, hyphens only, no spaces

2. **Agent Category**:
   - `product` - Product & Planning agents
   - `engineering` - Technical development agents
   - `quality` - Testing & validation agents
   - `design` - UI/UX design agents
   - `specialized` - Cross-cutting concerns

3. **Primary Responsibilities** (3-5 key areas):
   - What specific tasks will this agent handle?
   - What expertise does it bring?
   - What deliverables will it produce?

4. **Phase Involvement**:
   - Phase 1 (Planning)
   - Phase 2 (Implementation)
   - Phase 3 (Validation)
   - Phase 4 (Finalization)
   - All Phases

5. **Tools Required**:
   - Read, Write, Edit (file operations)
   - Glob, Grep (search operations)
   - Bash (command execution)
   - Task (agent invocation)
   - Skill (skill execution)
   - mcp\_\_\* (MCP server tools)

6. **Model Preference**:
   - `sonnet` - Claude Sonnet (balanced, recommended)
   - `opus` - Claude Opus (complex reasoning)
   - `haiku` - Claude Haiku (fast, simple tasks)
   - `inherit` - Use parent model (default)

7. **Related Agents**:
   - Which agents will this agent collaborate with?
   - Which agents should it invoke?
   - Any agents being replaced or absorbed?

### Step 2: Agent File Structure Generation

**File Created**: `.claude/agents/{category}/{agent-name}.md`

**YAML Frontmatter Template**:

```yaml
---
name: {agent-name}
description: {One-line description of when to invoke this agent}
tools: {comma-separated list of allowed tools}
model: {sonnet|opus|haiku|inherit}
responsibilities:
  - {Primary responsibility 1}
  - {Primary responsibility 2}
  - {Primary responsibility 3}
---
```

**System Prompt Sections**:

1. **Role & Identity**
   - Clear role definition
   - Primary expertise areas
   - Authority and scope

2. **Core Responsibilities**
   - Detailed breakdown of each responsibility
   - Expected deliverables
   - Quality standards

3. **Working Context**
   - Technology stack relevant to this agent
   - Integration points

4. **Best Practices**
   - Domain-specific best practices
   - Anti-patterns to avoid
   - Quality checklists

5. **Workflow Integration**
   - When the agent is invoked
   - How it integrates with phases
   - Handoff protocols

6. **Quality Standards**
   - Acceptance criteria
   - Definition of done
   - Validation requirements

7. **Tools & Resources**
   - Specific tools used by this agent
   - Documentation references
   - External resources

8. **Examples**
   - Common scenarios
   - Example invocations
   - Sample deliverables

### Step 3: Integration & Documentation

**Updates Required**:

1. **Agent Registry (if applicable)**:
   - Add agent to category section
   - Update agent count statistics
   - Add to directory structure diagram

2. **Project Configuration (CLAUDE.md)**:
   - Add to Team Organization section if present
   - Update quick reference if needed

3. **Glossary/Documentation**:
   - Add agent example if pattern is new
   - Update agent naming examples

### Step 4: Validation & Testing

**Validation Checks**:

- [ ] Agent name follows kebab-case convention
- [ ] YAML frontmatter is valid
- [ ] All required sections present
- [ ] Responsibilities clearly defined
- [ ] Tools list is appropriate
- [ ] No overlap with existing agents
- [ ] Category placement correct
- [ ] Documentation updated
- [ ] File in correct directory

**Test Invocation**:

```
"Use the {agent-name} to help with {sample task}"
```

Verify:

- Agent loads correctly
- Prompt expands properly
- Agent has access to specified tools
- Agent follows defined responsibilities

### Step 5: Commit & Documentation

**Commit Message Format**:

```bash
feat(agents): add {agent-name} agent for {primary purpose}

- Add {agent-name} agent in {category} category
- Core responsibilities: {list 3-5 key areas}
- Integrates with: {related agents or phases}
- Tools: {key tools used}
- Model: {model preference}

Updates:
- .claude/agents/{category}/{agent-name}.md (new)
- Agent registry documentation (updated)
```

## Interactive Wizard Flow

```
Create New Agent Wizard
===================================================================

Step 1: Agent Identity
===================================================================

Agent Name (kebab-case): graphql-engineer
Category:
  1. product - Product & Planning
  2. engineering - Technical Development
  3. quality - Testing & Validation
  4. design - UI/UX Design
  5. specialized - Cross-cutting Concerns

Select category (1-5): 2

One-line description:
> Designs and implements GraphQL schemas, resolvers, and queries
> for type-safe API development during implementation

===================================================================

Step 2: Responsibilities
===================================================================

Enter 3-5 primary responsibilities (one per line, empty line to finish):

1. GraphQL schema design and implementation
2. Resolver development with database integration
3. Query optimization and performance tuning
4. Type generation and validation
5. GraphQL testing and documentation
6.

===================================================================

Step 3: Configuration
===================================================================

Tools needed (select all that apply):
  [x] Read, Write, Edit - File operations
  [x] Glob, Grep - Search operations
  [x] Bash - Command execution
  [ ] Task - Agent invocation
  [ ] Skill - Skill execution

Model preference:
  1. sonnet - Claude Sonnet (balanced)
  2. opus - Claude Opus (complex reasoning)
  3. haiku - Claude Haiku (fast tasks)
  4. inherit - Use parent model

Select model (1-4): 1

Phase involvement:
  [ ] Phase 1 - Planning
  [x] Phase 2 - Implementation
  [ ] Phase 3 - Validation
  [ ] Phase 4 - Finalization
  [ ] All Phases

===================================================================

Step 4: Relationships
===================================================================

Related agents (comma-separated):
> db-engineer, api-engineer, tech-lead

===================================================================

Step 5: Review & Confirm
===================================================================

Agent Summary:
  Name: graphql-engineer
  Category: engineering
  Description: Designs and implements GraphQL schemas...
  Responsibilities: 5 defined
  Tools: Read, Write, Edit, Glob, Grep, Bash
  Model: sonnet
  Phases: Phase 2 (Implementation)
  Related: db-engineer, api-engineer, tech-lead

File will be created at:
  .claude/agents/engineering/graphql-engineer.md

Proceed with creation? (y/n): y

===================================================================

Creating Agent
===================================================================

Done: Generated agent file
Done: Updated documentation
Done: Validation passed

Agent created successfully!

File: .claude/agents/engineering/graphql-engineer.md

Next steps:
1. Review and customize the generated content
2. Add specific examples and best practices
3. Test agent invocation
4. Commit changes
```

## Agent Template Structure

### Technical Agent Template

```markdown
---
name: {agent-name}
description: {description}
tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
responsibilities:
  - {responsibility-1}
  - {responsibility-2}
  - {responsibility-3}
---

# {Agent Name} Agent

## Role & Identity

You are a **{Title}** specialized in {expertise area}. Your primary focus is
{primary focus}.

**Core Expertise:**

- {expertise-1}
- {expertise-2}
- {expertise-3}

**Authority:** {what this agent can decide/do autonomously}

## Core Responsibilities

### 1. {Responsibility Category 1}

**Tasks:**
- {task-1}
- {task-2}
- {task-3}

**Deliverables:**
- {deliverable-1}
- {deliverable-2}

**Quality Standards:**
- {standard-1}
- {standard-2}

### 2. {Responsibility Category 2}

[Similar structure...]

## Working Context

### Technology Stack

**Primary Technologies:**
- {tech-1}: {usage}
- {tech-2}: {usage}

### Integration Points

**Works With:**
- `{agent-1}`: {collaboration}
- `{agent-2}`: {collaboration}

## Best Practices

### Do's
- {practice-1}
- {practice-2}
- {practice-3}

### Don'ts
- {anti-pattern-1}
- {anti-pattern-2}
- {anti-pattern-3}

### Quality Checklist

Before completing work, verify:
- [ ] {checklist-item-1}
- [ ] {checklist-item-2}
- [ ] {checklist-item-3}

## Workflow Integration

### Invocation Triggers

Invoke this agent when:
- {trigger-1}
- {trigger-2}
- {trigger-3}

## Tools & Resources

### Allowed Tools
- **Read/Write/Edit**: {usage}
- **Glob/Grep**: {usage}
- **Bash**: {usage}

## Examples

### Example 1: {Scenario}

**User Request:**
> {example-request}

**Process:**
1. {step-1}
2. {step-2}
3. {step-3}
```

## Validation Rules

### Agent Name

- **Format**: kebab-case only
- **Length**: 3-30 characters
- **Pattern**: `^[a-z][a-z0-9-]*[a-z0-9]$`
- **Uniqueness**: Must not conflict with existing agents
- **Descriptive**: Should clearly indicate role/expertise

### YAML Frontmatter

- **Required Fields**: name, description, tools, model, responsibilities
- **Valid Tools**: Read, Write, Edit, Glob, Grep, Bash, Task, Skill, mcp__*
- **Valid Models**: sonnet, opus, haiku, inherit
- **Responsibilities**: 3-10 items minimum

### Directory Structure

```
.claude/agents/
  product/        # Product & Planning agents
  engineering/    # Technical development agents
  quality/        # Testing & validation agents
  design/         # UI/UX design agents
  specialized/    # Cross-cutting concerns
```

### File Naming

- **Pattern**: `{agent-name}.md`
- **Location**: `.claude/agents/{category}/{agent-name}.md`
- **Case**: All lowercase
- **Extension**: `.md` only

## Best Practices for Agent Design

### Clarity

- **Clear Scope**: Define exactly what the agent does and doesn't do
- **No Overlap**: Ensure no significant overlap with existing agents
- **Focused**: Keep responsibilities related and cohesive

### Completeness

- **Comprehensive**: Include all sections from template
- **Examples**: Provide multiple realistic examples
- **Checklists**: Include actionable quality checklists

### Integration

- **Workflow Aware**: Clearly define phase integration
- **Collaboration**: Specify how agent works with others
- **Handoffs**: Define clear input/output protocols

### Maintainability

- **Documentation**: Keep inline documentation current
- **Examples**: Update examples as patterns evolve
- **Standards**: Follow all project standards

## Common Patterns

### Backend Development Agent

- Category: engineering
- Tools: Read, Write, Edit, Bash
- Model: sonnet
- Phases: Phase 2 (Implementation)

### Quality Assurance Agent

- Category: quality
- Tools: Read, Bash, Skill
- Model: sonnet
- Phases: Phase 3 (Validation), All Phases

### Product Agent

- Category: product
- Tools: Read, Write, Edit
- Model: sonnet
- Phases: Phase 1 (Planning)

## Related Commands

- `/create-command` - Create new command
- `/create-skill` - Create new skill
- `/help` - Get system help

## Notes

- **Agent Consolidation**: Before creating a new agent, consider if responsibilities could be absorbed by an existing agent
- **Specialized vs General**: Prefer specialized agents for deep expertise, general agents for broad coordination
- **Tool Access**: Only grant tools that the agent actually needs
- **Model Selection**: Use sonnet for most cases, opus only for complex reasoning requirements
- **Testing**: Always test agent invocation before committing
