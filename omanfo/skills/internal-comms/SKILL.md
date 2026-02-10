---
name: internal-comms
description: Resources for writing internal communications — status reports, leadership updates, 3P updates, company newsletters, FAQs, incident reports, and project updates. Use when asked to write any sort of internal communication. Complements Okyeame status reporting patterns (/sitrep, /recap).
---

# Internal Communications

## When to Use

Write any kind of internal communication:
- 3P updates (Progress, Plans, Problems)
- Status reports and leadership updates
- Company newsletters
- FAQ responses
- Project updates
- Incident reports

## Communication Types

### 3P Update (Progress, Plans, Problems)

```markdown
## Progress (What happened)
- [Completed item with impact]
- [Milestone reached]

## Plans (What's next)
- [Upcoming work with timeline]
- [Dependencies or coordination needed]

## Problems (What's blocked)
- [Blocker]: [Impact]. [Ask/mitigation].
```

### Leadership Update

```markdown
Status: [Green / Yellow / Red]

TL;DR: [One sentence — the most important thing to know]

Progress:
- [Outcome tied to goal/OKR]

Risks:
- [Risk]: [Mitigation]. [Ask if needed].

Decisions needed:
- [Decision]: [Options with recommendation]. Need by [date].
```

### Incident Report

```markdown
## Incident Summary
- **What happened**: [Brief description]
- **Impact**: [Who was affected, severity, duration]
- **Root cause**: [What went wrong]
- **Resolution**: [How it was fixed]

## Timeline
- [Time]: [Event]

## Action Items
- [ ] [Preventive measure] — Owner: [name], Due: [date]
```

### Project Update

```markdown
## Status: [On Track / At Risk / Off Track]

### Completed This Period
- [Item with link to PR/issue]

### In Progress
- [Item] — [Owner]. [Expected completion].

### Blocked
- [Item]: [Blocker]. [What's needed to unblock].

### Next Period
- [Planned work]
```

## Writing Guidelines

- **Lead with the conclusion**, not the journey
- **Be specific**: "Shipped auth module, reduced login time by 40%" not "Made progress on auth"
- **Keep it scannable**: bullets, headers, bold for key terms
- **Status colors matter**: Yellow is proactive risk management, not failure
- **Asks must be specific**: "Decision on X by Friday" not "support needed"
- **Match the audience**: executives want strategy, engineers want details

## Keywords

3P updates, company newsletter, weekly update, status report, leadership update, FAQs, incident report, project update, internal comms

## Attribution

From [anthropics/skills](https://github.com/anthropics/skills) `internal-comms` skill (see LICENSE.txt in source repo for terms).
