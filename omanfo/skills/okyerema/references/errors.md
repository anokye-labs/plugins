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

## Error: 'copilot' not found when assigning to Copilot via gh CLI

**Cause:** Using `--add-assignee "copilot"` (without `@` prefix) in the `gh issue edit` command.

**Fix:** Always include the `@` prefix:
```bash
# ✅ Works
gh issue edit {number} --add-assignee "@copilot"

# ❌ Fails with "'copilot' not found"
gh issue edit {number} --add-assignee "copilot"
```

Note: The REST API uses a different pattern — capital `C`, no `@`:
```bash
gh api repos/{owner}/{repo}/issues/{number}/assignees \
  --method POST \
  -f 'assignees[]=Copilot'
```

---

## Error: GraphQL `addAssigneesToAssignable` returns NOT_FOUND for Copilot

**Cause:** Attempting to assign Copilot via GraphQL. Copilot's node ID (e.g., `BOT_kgDOC9w8XQ`) is a BOT type, not a User type. GraphQL mutations only accept User-type node IDs for assignees.

**Fix:** Use the REST API endpoint instead of GraphQL:
```bash
gh api repos/{owner}/{repo}/issues/{number}/assignees \
  --method POST \
  -f 'assignees[]=Copilot'
```

The following GraphQL mutation will NOT work for Copilot:
```graphql
# ❌ Returns NOT_FOUND — BOT-type node IDs are not accepted
mutation {
  addAssigneesToAssignable(input: {
    assignableId: "I_issue_node_id"
    assigneeIds: ["BOT_kgDOC9w8XQ"]
  }) {
    assignable { id }
  }
}
```

---

## Error: Copilot not found in `/assignees` or `/collaborators` endpoints

**Cause:** Attempting to verify Copilot availability before assigning by querying the standard endpoints. Copilot does NOT appear in these lists even when enabled at the org level.

```bash
# ❌ Copilot will NOT appear in these results even when enabled
gh api repos/{owner}/{repo}/assignees
gh api repos/{owner}/{repo}/collaborators
```

**Fix:** Do not pre-validate Copilot availability via these endpoints. Org-level enablement is required and must be verified via GitHub org settings (not the API). Assignment scripts must handle errors gracefully rather than checking first:
- Attempt the assignment directly
- Catch and surface errors (e.g., 422 Unprocessable Entity) as actionable messages
- Direct users to check GitHub org settings → Copilot → coding agent if assignment fails

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
