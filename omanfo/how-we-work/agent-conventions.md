# Agent Behavior Conventions

This document defines the behavioral expectations for AI agents working in Anokye Labs repositories. These conventions ensure agents operate effectively, safely, and consistently with our coordination protocols.

## Core Principles

### 1. Action-First (Not Advisory)

**Rule:** Agents act. They do not advise, suggest, or propose. When assigned work, they complete it.

**Do:**
```
✅ Created issue #42 (Task: Add validation)
✅ Fixed authentication bug in auth.ts
✅ Updated documentation in README.md
```

**Don't:**
```
❌ "I suggest you create an issue for this"
❌ "You might want to consider adding validation"
❌ "Here are some options you could try"
```

**Why:** Agents are autonomous workers, not consultants. If an agent cannot complete work, it should report the blocker and stop — not provide advice.

**Reference:** anokye-labs/plugins#71

### 2. Branch-Awareness

**Rule:** Before making changes, agents must verify they're on the correct branch. Guard against operating on the wrong branch.

**Required checks:**
```bash
# Always check before committing
git branch --show-current
git status
```

**Pattern:**
1. Read issue description for branch context
2. Verify current branch matches expected branch
3. If on wrong branch, STOP and report
4. Never assume or "fix" by switching branches

**Why:** Working on the wrong branch can merge incomplete work, overwrite others' changes, or break main/production.

**Reference:** anokye-labs/plugins#68

### 3. Read-Docs-Before-Debug

**Rule:** When encountering errors or unfamiliar systems, consult documentation before trial-and-error debugging.

**Priority order:**
1. **Project docs** — README, how-we-work/, CONTRIBUTING
2. **Code comments** — Inline explanations
3. **Official docs** — Language/framework documentation
4. **Error messages** — Read them fully, search for exact text
5. **Trial-and-error** — Last resort only

**Pattern:**
```
❌ Hit error → try random fix → try another → ask human
✅ Hit error → read docs → understand → implement correct fix
```

**Why:** Random debugging wastes time, introduces new bugs, and misses root causes. Documentation provides context and correct patterns.

**Reference:** anokye-labs/plugins#67

### 4. OODA Loop Execution

**Rule:** Agents follow the Observe → Orient → Decide → Act cycle for all work.

**1. Observe**
- Read the issue body completely
- Check sub-issues and dependencies
- Review recent commits and changes
- Understand current state

**2. Orient**
- What is the goal?
- What are the constraints?
- What documentation or patterns exist?
- What are the dependencies?

**3. Decide**
- Choose the approach
- Identify files to change
- Plan the sequence of work

**4. Act**
- Make minimal, precise changes
- Verify each change
- Document in commit messages
- Update the issue

**Why:** Structured thinking prevents rework, reduces errors, and produces better solutions.

**Reference:** anokye-labs/plugins#55

### 5. Issue References in Commits

**Rule:** Every commit message must reference the issue being worked on.

**Format:**
```
<short description> (#<issue-number>)

Optional longer description if needed.

Refs: #<issue-number>
```

**Examples:**
```
✅ Add validation for user input (#42)
✅ Fix authentication token refresh (#108)
✅ Update OODA loop documentation (#29)
```

**Why:** Commit-issue traceability enables understanding why changes were made, tracking progress, and auditing work.

**Reference:** anokye-labs/plugins#55

## Coordination Protocols

### 6. GitHub Issues as External Memory

**Principle:** Issues are not just task descriptions — they are the shared memory and contract between agents and humans.

**Agent responsibilities:**
- Read issue body before starting work
- Update issue with progress and blockers
- Close issue when work is complete and verified
- Reference related issues in updates

**Issue body structure:**
```markdown
## Context
<Background and motivation>

## What to do
<Specific, actionable requirements>

## Acceptance criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Dependencies
Blocked by: #7, #12
```

**Why:** Issues provide persistent context across sessions. Agents are stateless; issues are the memory.

**Reference:** anokye-labs/plugins#55

### 7. Sub-Issues for Decomposition

**Rule:** Use GitHub's sub-issues API for parent-child relationships. This replaced the deprecated tasklists approach as of April 2025.

**Creating sub-issues:**
```graphql
# 1. Look up the issue type ID for your repository
query {
  repository(owner: "owner", name: "repo-name") {
    issueTypes(first: 10) {
      nodes {
        id
        name
      }
    }
  }
}

# 2. Create the child issue using the issueTypeId
mutation {
  createIssue(input: {
    repositoryId: "R_xxx"
    title: "Child Task"
    body: "Description"
    issueTypeId: "IT_xxx"  # Use the ID from step 1
  }) {
    issue { id number }
  }
}

# 3. Link child to parent using addSubIssue
mutation {
  addSubIssue(input: {
    issueId: "I_parent_xxx"
    subIssueId: "I_child_xxx"
  }) {
    issue { id }
    subIssue { id }
  }
}
```

**Query sub-issues (requires GraphQL-Features header):**
```powershell
gh api graphql -H "GraphQL-Features: sub_issues" -f query='
query {
  repository(owner: "owner", name: "repo") {
    issue(number: 42) {
      title
      subIssues(first: 50) {
        nodes {
          number
          title
        }
      }
    }
  }
}'
```

**Hierarchy patterns:**
- **Epic → Feature → Task** (for complex work)
- **Epic → Task** (for simple work)
- **Feature → Task** (for standalone features)

**Why:** Proper hierarchy enables parallel work, clear ownership, and progress tracking. The sub-issues API creates relationships immediately (synchronous), unlike tasklists which required 2-5 minute delays.

**Reference:** anokye-labs/plugins#55, omanfo/.github/skills/okyerema/SKILL.md

### 8. Agent Assignment Protocol

**Rule:** Assign work to the Copilot agent using GraphQL `updateIssue` mutation with the bot's node ID. Standard CLI assignment to bot accounts is not supported.

**How to assign:**
```powershell
# 1. Get the issue node ID
$issueId = gh api graphql `
  -f owner='<owner>' `
  -f name='<repo>' `
  -F number=<issue-number> `
  -f query='query($owner:String!, $name:String!, $number:Int!) { 
    repository(owner: $owner, name: $name) { 
      issue(number: $number) { id } 
    } 
  }' --jq '.data.repository.issue.id'

# 2. Assign using the Copilot bot node ID
gh api graphql `
  -f issueId=$issueId `
  -f query='mutation($issueId: ID!) { 
    updateIssue(input: { 
      id: $issueId, 
      assigneeIds: ["BOT_kgDOC9w8XQ"]
    }) { 
      issue { number } 
    } 
  }'
```

**Notes:**
- The bot node ID (`BOT_kgDOC9w8XQ`) is specific to the organization's Copilot instance
- Assignment signals "this agent should work on this issue"
- Only assign when work is ready (dependencies resolved, requirements clear)
- Standard CLI (`gh issue edit --add-assignee "@copilot"`) does NOT work for bot accounts

**Why:** Explicit assignment creates accountability and prevents duplicate work. The GraphQL flow is required because standard CLI assignment to bot accounts is not supported.

**Reference:** omanfo/.github/skills/okyerema/references/agentic-workflows.md

## Observability

### 9. Structured Logging

**Rule:** Use consistent, parseable log formats for agent actions.

**Pattern:**
```
[<timestamp>] [<level>] [<component>] <message>
```

**Example:**
```
[2026-02-10T01:15:23Z] [INFO] [issue-creator] Created issue #42 (Task: Add validation)
[2026-02-10T01:16:45Z] [ERROR] [hierarchy-builder] Failed to link issue #42 to parent #40: NOT_FOUND
[2026-02-10T01:17:01Z] [WARN] [branch-guard] Current branch 'feature-x' does not match expected 'main'
```

**Levels:**
- **INFO** — Normal operations
- **WARN** — Unexpected but handled conditions
- **ERROR** — Failures requiring attention

**Why:** Structured logs enable debugging, auditing, and analytics.

**Reference:** anokye-labs/akwaaba#297

### 10. Progress Updates

**Rule:** Update issues regularly with progress, blockers, and decisions.

**When to update:**
- After completing a milestone
- When blocked
- Before context switches
- When closing the issue

**Format:**
```markdown
## Progress Update (2026-02-10)

**Completed:**
- [x] Created agent-conventions.md
- [x] Added evaluation scenario

**In Progress:**
- [ ] Updating plugin integration

**Blockers:**
None

**Next Steps:**
Verify installation with `copilot plugin list`
```

**Why:** Progress updates provide visibility and enable collaboration.

**Reference:** anokye-labs/plugins#55

## Quality Standards

### 11. Minimal, Surgical Changes

**Rule:** Make the smallest possible changes to achieve the goal.

**Principles:**
- Change as few lines as possible
- Preserve existing working code
- Don't "fix" unrelated issues
- Don't reformat unless required

**Example:**
```diff
❌ Rewrote entire function to "improve readability"
✅ Changed 2 lines to fix the bug
```

**Why:** Minimal changes reduce risk, simplify review, and make rollback easier.

**Reference:** Agent system instructions

### 12. Verify Before Committing

**Rule:** Test changes before committing. Run existing linters, builders, and test suites.

**Checklist:**
```bash
# 1. Lint
npm run lint  # or equivalent

# 2. Build
npm run build  # or equivalent

# 3. Test
npm run test  # or equivalent

# 4. Verify specific functionality
# Run targeted tests for changed areas
```

**When to skip:**
- Documentation-only changes
- No linter/builder/tests exist
- Custom agent completed the work (trust their verification)

**Why:** Catching errors early prevents broken builds and failed CI.

**Reference:** Agent system instructions

## Anti-Patterns

### What Agents Should NOT Do

❌ **Advise instead of act** — "You should consider adding tests"  
❌ **Make assumptions** — Guess at requirements instead of asking  
❌ **Ignore documentation** — Jump straight to trial-and-error  
❌ **Work on wrong branch** — Assume the current branch is correct  
❌ **Skip issue updates** — Complete work without documenting progress  
❌ **Commit without references** — Omit issue numbers from commits  
❌ **Make sweeping changes** — Rewrite files instead of surgical edits  
❌ **Skip verification** — Commit without testing  
❌ **Create labels for structure** — Use labels instead of issue types  
❌ **Use title prefixes for types** — `[Epic]` instead of setting actual type  

## Implementation in Omanfo

These conventions are implemented through:

1. **Plugin installation** — Conventions are included in `.github/skills/okyerema/`
2. **Skill instructions** — `SKILL.md` references these conventions
3. **Helper scripts** — PowerShell tools enforce patterns (e.g., issue creation, hierarchy)
4. **Evaluations** — Tests verify agents follow conventions

## References

### Akwaaba Issues
- [#293](https://github.com/anokye-labs/akwaaba/issues/293) — Agent archetypes and AGENTS.md
- [#294](https://github.com/anokye-labs/akwaaba/issues/294) — Agent archetype definitions
- [#295](https://github.com/anokye-labs/akwaaba/issues/295) — Actions-first design pattern
- [#296](https://github.com/anokye-labs/akwaaba/issues/296) — Error handling patterns
- [#297](https://github.com/anokye-labs/akwaaba/issues/297) — Observability and structured logging
- [#298](https://github.com/anokye-labs/akwaaba/issues/298) — Queue management
- [#299](https://github.com/anokye-labs/akwaaba/issues/299) — Agent lifecycle documentation
- [#300](https://github.com/anokye-labs/akwaaba/issues/300) — Code examples
- [#301](https://github.com/anokye-labs/akwaaba/issues/301) — Research source links

### Plugin Issues
- [#29](https://github.com/anokye-labs/plugins/issues/29) — This issue (Document agent behavior conventions)
- [#40](https://github.com/anokye-labs/plugins/issues/40) — Shared Agent Runner Module
- [#41](https://github.com/anokye-labs/plugins/issues/41) — Agent Archetype Templates
- [#55](https://github.com/anokye-labs/plugins/issues/55) — Agent behavior conventions (original)
- [#67](https://github.com/anokye-labs/plugins/issues/67) — Read-docs-before-debug principle
- [#68](https://github.com/anokye-labs/plugins/issues/68) — Branch-awareness principle
- [#71](https://github.com/anokye-labs/plugins/issues/71) — Action-first principle
- [#74](https://github.com/anokye-labs/plugins/issues/74) — Consolidated behavioral expectations

---

*[← Back to How We Work](../how-we-work.md) | [Getting Started →](./getting-started.md)*
