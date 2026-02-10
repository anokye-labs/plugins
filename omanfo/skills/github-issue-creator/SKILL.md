---
name: github-issue-creator
description: Convert raw notes, error logs, voice dictation, or screenshots into structured GitHub-flavored markdown issue reports. Use when creating issues from unstructured input, converting meeting notes to action items, or structuring bug reports from user feedback. Adapted from microsoft/skills for the Anokye System.
---

# GitHub Issue Creator

Convert unstructured input into well-structured GitHub issues using org-standard issue types (Epic, Feature, Task, Bug) and GraphQL mutations.

## When to Use

- Raw meeting notes with action items
- Error logs or stack traces that need bug reports
- Voice dictation or quick notes to formalize
- Screenshots with annotations to document
- User feedback to convert into feature requests

## Issue Structure

### Required Fields
- **Title**: Clear, action-oriented (verb + noun)
- **Body**: Structured markdown with sections
- **Issue Type**: Epic, Feature, Task, or Bug (use org issue type IDs)

### Body Template
```markdown
## Summary
[1-2 sentence description of what and why]

## Details
[Expanded context, requirements, or reproduction steps]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Notes
[Additional context, links, references]
```

## Issue Type Selection

| Type | When to Use |
|------|------------|
| **Epic** | Large initiative spanning multiple features |
| **Feature** | User-facing capability or enhancement |
| **Task** | Implementation work, chore, or technical item |
| **Bug** | Defect, regression, or unexpected behavior |

## Creation via GraphQL

Always use GraphQL mutations (never REST) for issue creation:

```graphql
mutation {
  createIssue(input: {
    repositoryId: "<REPO_ID>"
    title: "<title>"
    body: "<body>"
    issueTypeId: "<ISSUE_TYPE_ID>"
  }) {
    issue { number url }
  }
}
```

## From Raw Notes

When given unstructured input:
1. **Extract** the core intent (what needs to happen)
2. **Classify** as Epic, Feature, Task, or Bug
3. **Structure** with title, summary, details, acceptance criteria
4. **Enrich** with labels, assignees, or parent links if context available

## Best Practices

- Titles should be scannable: `Add retry logic to webhook delivery` not `Webhook issue`
- Include reproduction steps for bugs (Given/When/Then)
- Link to related issues using `#number` references
- Use sub-issues API for parent-child relationships
- One issue per concern — don't combine unrelated items

## Attribution

Adapted from [microsoft/skills](https://github.com/microsoft/skills) `github-issue-creator` skill (MIT License).
