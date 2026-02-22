# Common Errors & Fixes

**[← Back to SKILL.md](../SKILL.md)**

---

## Error: "Issue type not found"

**Cause:** Wrong type ID or type doesn't exist in organization.

**Fix:** Re-query organization types:
```graphql
query {
  organization(login: "anokye-labs") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}
```

---

## Error: Sub-issues query returns null or fails

**Cause:** Missing `GraphQL-Features: sub_issues` header.

**Fix:** Include the header in all sub-issues queries:
```bash
gh api graphql -H "GraphQL-Features: sub_issues" -f query='...'
```

---

## Error: Epic tracks both Features AND Tasks

**Cause:** Mixed hierarchy - Epic has both Features and Tasks as direct children.

**Fix:** Choose one pattern consistently:
- Either Epic → Features → Tasks (3-level)
- Or Epic → Tasks (2-level)

Use `removeSubIssue` mutation to unlink incorrect relationships:
```graphql
mutation {
  removeSubIssue(input: {
    issueId: "I_parent_id"
    subIssueId: "I_child_id"
  }) {
    issue { id }
    subIssue { id }
  }
}
```

---

## Error: GraphQL mutation `addTrackedByIssue` doesn't exist

**Cause:** Using deprecated tasklist-based API.

**Fix:** Use the sub-issues API with `addSubIssue` mutation:
```graphql
mutation {
  addSubIssue(input: {
    issueId: "I_parent_id"
    subIssueId: "I_child_id"
  }) {
    issue { id }
    subIssue { id }
  }
}
```

---

## Error: gh CLI can't set issue type

**Cause:** The `gh issue create` command has no `--type` flag.

**Fix:** Use GraphQL `createIssue` mutation with `issueTypeId` parameter.

---

## Error: Project field doesn't create issue relationship

**Cause:** Project custom fields are for tracking/visualization only.

**Fix:** Use sub-issues API for actual parent-child relationships. Project fields are separate.

---

## Error: "Cannot add sub-issue"

**Cause:** May be attempting to create circular dependency or invalid hierarchy.

**Fix:** Verify:
- Child is not already a parent of the target parent (no cycles)
- Both issues exist and have valid IDs
- Issue types support the relationship (Epic→Feature, Epic→Task, Feature→Task)

---

## Pre-Flight Checklist

Before starting any issue operations:

- [ ] I have the repository ID (`R_xxx`)
- [ ] I have organization issue type IDs (`IT_xxx`)
- [ ] I'm using GraphQL API (not gh CLI for types/relationships)
- [ ] I'm NOT using labels for types
- [ ] I've planned the hierarchy (3-level or 2-level?)
- [ ] I'm including `GraphQL-Features: sub_issues` header for sub-issues queries

**[← Back to SKILL.md](../SKILL.md)**
