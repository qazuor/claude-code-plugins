---
spec-id: "{{SPEC_ID}}"
type: "{{TYPE}}"
complexity: high
status: draft
created: "{{DATE}}"
---

# {{TITLE}}

## Part 1: Functional Specification

### Overview & Goals

What we're building, why, and how success is measured.

- **Goal**: [primary objective]
- **Motivation**: [business/technical driver]
- **Success metrics**: [measurable outcomes]
- **Target users**: [who benefits]

### User Stories & Acceptance Criteria

#### US-1: [Story Title]

**As a** [role], **I want** [action], **so that** [benefit].

**Acceptance Criteria:**

- **Given** [context], **When** [action], **Then** [result]
- **Given** [context], **When** [action], **Then** [result]
- **Given** [edge case], **When** [action], **Then** [graceful handling]

#### US-2: [Story Title]

**As a** [role], **I want** [action], **so that** [benefit].

**Acceptance Criteria:**

- **Given** [context], **When** [action], **Then** [result]

#### US-3: [Story Title]

**As a** [role], **I want** [action], **so that** [benefit].

**Acceptance Criteria:**

- **Given** [context], **When** [action], **Then** [result]

### UX Considerations

- **User flows**: [key user journeys]
- **Edge cases**: [unusual but valid scenarios]
- **Error states**: [how errors are presented to users]
- **Loading states**: [what users see during async operations]
- **Accessibility**: [a11y requirements]

### Out of Scope

Explicitly excluded items to prevent scope creep:

- [Item 1 - why excluded]
- [Item 2 - why excluded]
- [Item 3 - may be addressed in future spec]

## Part 2: Technical Analysis

### Architecture

System design, component interactions, and patterns.

- **Pattern**: [architectural pattern]
- **Components**: [new/modified components]
- **Integration points**: [where this connects to existing system]
- **Data flow**: [how data moves through the system]

### Data Model Changes

| Table/Schema | Change | Description |
|-------------|--------|-------------|
| [table] | [new/modify/delete] | [what changes] |

**Migrations needed**: [yes/no, details]

### API Design

#### [Method] /api/[path]

- **Auth**: [required level]
- **Request**: [body/params shape]
- **Response**: [response shape]
- **Errors**: [error codes and meanings]

### Dependencies

**External packages:**

| Package | Version | Purpose |
|---------|---------|---------|
| [pkg] | [ver] | [why needed] |

**Internal packages affected:**

- [package] - [how affected]

### Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| [Risk 1] | [H/M/L] | [H/M/L] | [strategy] |
| [Risk 2] | [H/M/L] | [H/M/L] | [strategy] |

### Performance Considerations

- **Expected load**: [requests/operations per time unit]
- **Bottlenecks**: [identified performance risks]
- **Optimization needs**: [caching, indexing, lazy loading, etc.]
- **Monitoring**: [what to track]

## Implementation Approach

High-level task breakdown and ordering (refined by plugin after approval).

### Phase 1: Setup

1. [ ] [Setup task]

### Phase 2: Core

2. [ ] [Core implementation task]
3. [ ] [Core implementation task]

### Phase 3: Integration

4. [ ] [Integration task]
5. [ ] [Integration task]

### Phase 4: Testing & Polish

6. [ ] [Testing task]
7. [ ] [Documentation task]
