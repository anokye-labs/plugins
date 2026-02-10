# Architecture Decision Record (ADR) Template

This template guides you in documenting significant architectural and design decisions. ADRs create a historical record of why decisions were made, helping future contributors understand the context and reasoning behind important choices.

## When to Use This Template

Create an ADR when you're making a decision that:
- Affects the structure, patterns, or technical direction of the system
- Has long-term implications for how the codebase evolves
- Involves significant tradeoffs between competing approaches
- Changes or introduces architectural patterns
- Requires buy-in from multiple stakeholders

See [ADR Process](./adr-process.md) for detailed guidance on when to create ADRs vs regular issues.

## Template

```markdown
# ADR-[number]: [Title]

**Status**: Proposed | Accepted | Deprecated | Superseded
**Date**: [YYYY-MM-DD]
**Deciders**: [List key people/teams involved in the decision]

## Context

[Describe the issue or situation that motivates the decision. Include:
- What problem are we trying to solve?
- What constraints or forces are at play?
- What's the current state that needs to change?
- Why does this decision matter?]

## Decision

[State the decision clearly and concisely. What approach have we chosen?
Be specific about what will be done.]

## Alternatives Considered

[List other options that were evaluated. For each:
- Brief description of the approach
- Why it was not chosen
- Key tradeoffs]

### Alternative 1: [Name]
- **Description**: ...
- **Pros**: ...
- **Cons**: ...
- **Why not chosen**: ...

### Alternative 2: [Name]
- **Description**: ...
- **Pros**: ...
- **Cons**: ...
- **Why not chosen**: ...

## Consequences

Document the outcomes of this decision:

### Positive
- [What becomes easier or better?]
- [What capabilities does this unlock?]

### Negative
- [What becomes harder?]
- [What are we giving up?]
- [What new problems might this create?]

### Neutral
- [What changes but is neither clearly good nor bad?]
- [What new responsibilities or maintenance does this introduce?]

## Implementation

[Optional section for implementation notes:
- Key steps to implement this decision
- Migration path if changing from previous approach
- Timeline or phases if applicable]

## References

[Links to related documents, discussions, or resources:
- GitHub issues or PRs
- Design documents
- External articles or documentation
- Related ADRs]
```

## Example ADR

For a concrete example, see the ADR template in the [product-management skill](../.github/skills/product-management/SKILL.md#architecture-decision-record-adr), which includes a simplified format suitable for quick architectural decisions.

## Numbering Convention

ADRs should be numbered sequentially starting from 001:
- ADR-001: [First decision]
- ADR-002: [Second decision]
- ADR-003: [Third decision]

Store ADRs in a dedicated `docs/adr/` or `decisions/` directory in your repository.

## Status Lifecycle

- **Proposed**: Decision is being discussed, not yet finalized
- **Accepted**: Decision has been approved and is in effect
- **Deprecated**: Decision is no longer recommended but may still be in use
- **Superseded**: Decision has been replaced by a newer ADR (link to it)

## Attribution

This template is inspired by [Michael Nygard's ADR format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) and adapted for the Anokye System. The product-management skill provides an alternative lightweight format for simpler decisions.

---

*[← Back to How We Work](../how-we-work.md) | [ADR Process Guide →](./adr-process.md)*
