---
name: skill-creator
description: Guide for creating effective skills that extend AI agent capabilities with specialized knowledge, workflows, or tool integrations. Use when creating a new skill, updating an existing skill, or reviewing skill design for quality and token efficiency. Adapted from microsoft/skills.
---

# Skill Creator Guide

Create well-structured skills that follow progressive disclosure, maintain token efficiency, and provide clear activation triggers.

## Skill File Structure

Every skill needs a `SKILL.md` file with YAML frontmatter:

```yaml
---
name: my-skill
description: >
  Trigger-rich description under 1024 chars. Include verbs and nouns
  that users would naturally say. This is how the agent discovers
  when to activate this skill.
---
```

## Progressive Disclosure Architecture

Skills load in three tiers to conserve context:

### Tier 1: Metadata (30-50 tokens)
- `name` and `description` from frontmatter
- Always loaded — this is how the agent decides to activate
- **Must be trigger-rich**: include action verbs, file types, domain terms

### Tier 2: Instructions (<500 lines)
- The SKILL.md body — loaded when skill activates
- Core workflow, quick start, critical rules
- **No preamble** — start with actionable content immediately

### Tier 3: References (on-demand)
- Files in `references/` directory — loaded only when needed
- Detailed docs, examples, API specs, troubleshooting
- Each file must be self-contained and focused

## SKILL.md Authoring Rules

### Frontmatter Description
- **Under 1024 characters**
- Use trigger phrases: verbs users say + nouns they mention
- Focus on **when to use** over **what it does**
- Bad: `"Helps with documents"` — too vague
- Good: `"Use when creating Word docs, editing .docx files, generating reports with tables and formatting"`

### Body Content
- **Under 500 lines** — this is a hard budget
- Start with a quick start or core workflow (no introductions)
- Use imperative language: "Create the file" not "You should create the file"
- Include concrete examples with input/output pairs
- Link to `references/` for anything that would push over 500 lines

### References Directory
- Single depth only: `references/FILE.md` (no nesting)
- Each file is self-contained — don't require reading multiple files
- Name files descriptively: `MODELS.md`, `WORKFLOWS.md`, `API.md`
- Include a brief description at the top of each reference file

## Common Patterns

### Workflow-Oriented Skills
Organize around user workflows, not API endpoints:

```markdown
## Creating a Report
1. Gather data from source
2. Format using template
3. Export to target format

## Editing an Existing Report
1. Load the file
2. Apply changes
3. Validate and save
```

### Tool Integration Skills
When wrapping external tools or APIs:

```markdown
## Quick Start
[Minimal example to get started]

## Core Operations
[3-5 most common operations with examples]

## Error Handling
[What to do when things go wrong — guide next steps]

## References
- [FULL_API.md](references/FULL_API.md) — Complete API reference
- [EXAMPLES.md](references/EXAMPLES.md) — Extended examples
```

### Script-Backed Skills
When skills include PowerShell or other scripts:

```markdown
## Available Scripts
| Script | Purpose |
|--------|---------|
| `scripts/Do-Thing.ps1` | Brief description |

## Usage
[How and when to invoke each script]
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why It's Bad | Fix |
|-------------|-------------|-----|
| SKILL.md > 500 lines | Consumes context budget | Move detail to references/ |
| Vague description | Agent can't discover skill | Add trigger verbs and nouns |
| Nested references | Complexity, hard to find | Single-depth references/ only |
| No examples | Agent guesses at usage | Add concrete input/output pairs |
| API-oriented structure | Doesn't match user intent | Organize by workflow |
| Generic error messages | Agent can't recover | Guide next steps in errors |

## Quality Checklist

- [ ] Frontmatter description < 1024 chars with trigger phrases
- [ ] SKILL.md body < 500 lines
- [ ] Quick start with no preamble
- [ ] Concrete examples with input/output
- [ ] References are single-depth and self-contained
- [ ] Error responses guide next steps
- [ ] Imperative language throughout
- [ ] Consistent terminology

## Attribution

Adapted from [microsoft/skills](https://github.com/microsoft/skills) `skill-creator` skill (MIT License).
