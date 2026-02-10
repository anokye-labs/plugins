# ADR Process: When to Document Architectural Decisions

Architecture Decision Records (ADRs) document significant technical decisions that shape how a system evolves. This guide helps you decide when to create an ADR versus a regular GitHub issue.

## Quick Decision Tree

```
Is this a decision that affects system architecture,
patterns, or long-term technical direction?
    │
    ├─ YES ──> Does it involve significant tradeoffs
    │          or have lasting implications?
    │              │
    │              ├─ YES ──> Create an ADR
    │              │
    │              └─ NO ──> Create a Task/Feature issue
    │
    └─ NO ──> Create a regular issue (Task, Feature, Bug)
```

## When to Create an ADR

Create an Architecture Decision Record when:

### 1. **Architectural Patterns & Structure**
- Choosing a system architecture (microservices vs monolith, event-driven vs request-response)
- Selecting core frameworks or platforms
- Defining code organization patterns
- Establishing data flow or communication patterns

**Example**: "ADR-001: Use GitHub Issues as the coordination protocol for multi-agent systems"

### 2. **Technology Choices**
- Selecting databases, message queues, or infrastructure components
- Choosing programming languages for new components
- Adopting major libraries or frameworks
- Making build tool or deployment platform decisions

**Example**: "ADR-002: Use GraphQL for all structured GitHub operations instead of REST API"

### 3. **Cross-Cutting Concerns**
- Authentication and authorization approaches
- Logging, monitoring, and observability strategies
- Error handling patterns
- Security policies and practices

**Example**: "ADR-003: Use PowerShell 7+ for all automation scripts"

### 4. **Integration & Interfaces**
- API design decisions (REST vs GraphQL, versioning strategy)
- External service integration patterns
- Plugin or extension architecture
- Contract definitions between components

**Example**: "ADR-004: Use organization issue types instead of labels for structural classification"

### 5. **Significant Tradeoffs**
- Decisions where you're explicitly choosing one significant advantage over another
- When you need to document why you didn't choose popular alternatives
- When the decision has known downsides that future maintainers need to understand

**Example**: "ADR-005: Accept 2-5 minute delay for tasklist relationship updates in exchange for GitHub-native implementation"

## When to Create a Regular Issue Instead

Use regular GitHub issues (Task, Feature, Bug, Epic) when:

### Task Issues
- Implementing a feature that's already been decided
- Fixing a bug
- Writing documentation
- Performing routine maintenance
- Completing a clearly defined work item

**Example**: "Task: Convert generate.sh to PowerShell" (implementation work, not a decision)

### Feature Issues
- Adding new functionality within existing patterns
- Building a feature following established architecture
- Grouping related implementation tasks

**Example**: "Feature: PowerShell Script Conversion" (execution, not architectural decision)

### Bug Issues
- Something is broken and needs fixing
- Behavior doesn't match specification
- Performance problems

**Example**: "Bug: API timeout when processing large images"

### Epic Issues
- Large initiatives with multiple features
- Project phases
- Major milestones

**Example**: "Epic: Phase 2 - fal.ai Integration"

## The Gray Area: When It Could Be Either

Some decisions are borderline. Here's how to decide:

| Signal | → ADR | → Regular Issue |
|--------|-------|-----------------|
| **Reversibility** | Hard to reverse | Easy to change later |
| **Impact Scope** | System-wide | Localized to one component |
| **Tradeoffs** | Significant pros/cons | Clear best choice |
| **Precedent** | Sets pattern for future | One-off implementation |
| **Documentation Value** | Future devs need context | Self-explanatory from code |

### Example: "Should we use TypeScript for this new component?"

- **ADR** if: This sets the pattern for all future components (precedent)
- **Task** if: One component needs TypeScript for specific library compatibility (one-off)

### Example: "Should we add caching?"

- **ADR** if: Defining caching strategy for the entire system (pattern)
- **Task** if: Adding cache to specific slow endpoint (implementation)

## Integration with Product Management

The [product-management skill](../.github/skills/product-management/SKILL.md) (installed with Omanfo) provides a **lightweight ADR template** suitable for quick architectural decisions during feature development. Use it when:

- You need to document a decision quickly during active development
- The decision is important but doesn't require extensive alternatives analysis
- You're embedding the ADR in a feature spec or PR description

For formal architectural decisions that will guide the project long-term, use the [full ADR template](./adr-template.md).

## ADRs and Governance

As noted in akwaaba issues #302-#310, ADRs are part of a larger governance framework:

- **ADRs** document architectural and technical decisions
- **GOVERNANCE.md** documents the process, workflow, and organizational decisions
- **Branch protection rules** enforce technical standards (issue #304)
- **Commit validation** ensures quality gates (issue #305)
- **Issue-driven workflow** connects all work to tracked items (issue #307)

See [anokye-labs/plugins#38](https://github.com/anokye-labs/plugins/issues/38) for the governance workflow template implementation.

## Storing ADRs

### In Your Repository

Create a dedicated directory:
```
docs/adr/
├── README.md           # Index of all ADRs
├── ADR-001-title.md
├── ADR-002-title.md
└── ADR-003-title.md
```

### Lightweight Alternative

For projects with few architectural decisions, store ADRs in:
- `docs/decisions/`
- The main `README.md` or `ARCHITECTURE.md`
- Wiki pages

### As GitHub Issues

Some teams create ADRs as GitHub issues with an `adr` label. This works when:
- You want discussions to happen inline
- You're already using issues for all documentation
- You want native search and filtering

**Pros**: Integrated with issue workflow, searchable, supports discussions
**Cons**: Less permanent feeling, can get lost in issue list, harder to browse chronologically

## ADR Maintenance

### Updating ADRs

- **Never change the decision** — ADRs are historical records
- **Update status** — Mark as Deprecated or Superseded when replaced
- **Add notes** — Append "## Update [date]" sections for learnings
- **Link to successors** — Point to the new ADR that replaces this one

### When to Supersede

Create a new ADR that supersedes an old one when:
- You're reversing or significantly changing an architectural decision
- New constraints make the original decision no longer viable
- You've learned something that invalidates the original reasoning

**Format**: "ADR-012: Switch from REST to GraphQL (supersedes ADR-003)"

## Example Workflow

### Scenario: Choosing a Database

1. **Recognition**: Team realizes they need to decide on a database
2. **Discussion**: Initial conversations happen in Slack, meetings, or a GitHub issue
3. **Draft ADR**: Someone creates "ADR-007-choose-database.md" with status "Proposed"
4. **Review**: Team reviews alternatives, discusses tradeoffs
5. **Decision**: Team agrees, ADR status changes to "Accepted"
6. **Implementation**: Regular Task issues are created to implement the decision
7. **Reference**: Future PRs reference "ADR-007" when making database-related choices

## Tips

### Do
- ✅ Create ADRs before implementation begins (when possible)
- ✅ Document the alternatives you considered
- ✅ Be honest about tradeoffs and downsides
- ✅ Link to ADRs from related code and documentation
- ✅ Keep ADRs focused and readable

### Don't
- ❌ Write ADRs for decisions that have already been made and implemented (historical decisions without context)
- ❌ Use ADRs as general documentation (use docs/ instead)
- ❌ Create an ADR for every small technical choice
- ❌ Update or delete ADRs when decisions change (supersede instead)
- ❌ Write 20-page ADRs (aim for 2-4 pages)

## Attribution

Inspired by:
- [Michael Nygard's ADR format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Architectural Decision Records (ADR) GitHub organization](https://adr.github.io/)
- akwaaba PR #75 which established the ADR process for Anokye Labs
- The product-management skill's lightweight ADR template

---

*[← Back to How We Work](../how-we-work.md) | [ADR Template →](./adr-template.md)*
