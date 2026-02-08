---
name: product-management
description: "Use this skill for product management tasks: writing PRDs and feature specs, managing roadmaps, stakeholder communications, competitive analysis, metrics tracking, and user research synthesis. Triggers: \"PRD\", \"feature spec\", \"roadmap\", \"stakeholder update\", \"competitive analysis\", \"metrics\", \"OKR\", \"user research\", \"persona\", \"RICE score\"."
---

# Product Management

A unified skill for product strategy, planning, and communication.

## Capabilities

| Domain | Use When |
|--------|----------|
| Feature Spec | Writing PRDs, user stories, acceptance criteria |
| Roadmap | Prioritizing features, capacity planning, Now/Next/Later |
| Stakeholder Comms | Executive updates, ADRs, engineering briefs |
| Competitive Analysis | Landscape mapping, feature comparison, positioning |
| Metrics Tracking | North Star metrics, OKRs, dashboard design |
| User Research | Thematic analysis, personas, opportunity sizing |

## Feature Spec (PRD)

### Structure
1. **Problem Statement** — What problem, who has it, evidence
2. **Proposed Solution** — High-level approach, key features
3. **User Stories** — `As a [role], I want [action] so that [benefit]`
4. **Acceptance Criteria** — Given/When/Then format
5. **Technical Considerations** — Architecture, dependencies, risks
6. **Success Metrics** — How we'll measure impact
7. **Timeline** — Milestones and phases

### User Story Template
```markdown
**As a** [user role]
**I want** [capability]
**So that** [business value]

Acceptance Criteria:
- [ ] Given [context], when [action], then [result]
```

## Roadmap Management

### Now / Next / Later Framework
- **Now** (0-6 weeks): Committed, resourced, in progress
- **Next** (6-12 weeks): Planned, scoped, awaiting capacity
- **Later** (3-6 months): Directional, needs validation

### Prioritization: RICE
- **Reach**: How many users affected per quarter?
- **Impact**: How much does it move the metric? (3=massive, 2=high, 1=medium, 0.5=low, 0.25=minimal)
- **Confidence**: How sure are we? (100%=high, 80%=medium, 50%=low)
- **Effort**: Person-months to ship

**Score = (Reach × Impact × Confidence) / Effort**

### MoSCoW for scope decisions
- **Must have**: Ship fails without it
- **Should have**: Important but workaround exists
- **Could have**: Nice-to-have, cut if needed
- **Won't have**: Explicitly out of scope (this release)

## Stakeholder Communications

### Executive Update Template
```markdown
## [Product] Status — [Date]
**Status**: 🟢 On Track / 🟡 At Risk / 🔴 Off Track

### Key Outcomes
- [Metric]: [Current] vs [Target] ([trend])

### Decisions Needed
1. [Decision]: [Options]. Recommend [X] because [reason]. Need by [date].

### Risks (ROAM)
- [Resolved | Owned | Accepted | Mitigated]: [Description]
```

### Architecture Decision Record (ADR)
```markdown
# ADR-[number]: [Title]
**Status**: Proposed | Accepted | Deprecated | Superseded
**Date**: [YYYY-MM-DD]

## Context
[Why this decision is needed]

## Decision
[What we decided]

## Consequences
- [Positive]: ...
- [Negative]: ...
- [Neutral]: ...
```

## Competitive Analysis

### Landscape Map
```markdown
| Competitor | Positioning | Strengths | Weaknesses | Threat Level |
|-----------|-------------|-----------|------------|-------------|
| [Name] | [Market position] | [Key advantages] | [Key gaps] | High/Med/Low |
```

### Feature Comparison Matrix
```markdown
| Feature | Us | Comp A | Comp B |
|---------|-------|--------|--------|
| [Feature] | ✅ Full | ⚠️ Partial | ❌ None |
```

## Metrics & OKRs

### North Star Metric
One metric that captures core value delivery. All L1/L2 metrics ladder up to it.

### OKR Template
```markdown
**Objective**: [Qualitative, inspirational goal]

KR1: [Metric] from [baseline] to [target] by [date]
KR2: [Metric] from [baseline] to [target] by [date]
KR3: [Metric] from [baseline] to [target] by [date]
```

### Dashboard Design
- Lead indicators (predict future): activation rate, feature adoption
- Lag indicators (confirm past): revenue, churn, NPS

## User Research Synthesis

### Thematic Analysis
1. Gather raw observations/quotes
2. Code into themes (bottom-up)
3. Group themes into categories
4. Identify patterns across participants
5. Quantify: "7 of 10 participants mentioned X"

### Persona Template
```markdown
## [Name] — [Role/Archetype]
**Demographics**: [Age range, role, company size]
**Goals**: [What they're trying to achieve]
**Pain Points**: [What frustrates them]
**Behaviors**: [How they currently solve the problem]
**Quote**: "[Representative quote from research]"
```

### Opportunity Sizing
**TAM × SAM × SOM** or **# Users × Frequency × Value per use**

## Attribution

Consolidated from [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) `product-management` plugin (source-available license).
