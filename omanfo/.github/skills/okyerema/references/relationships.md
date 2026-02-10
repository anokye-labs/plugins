# Relationships Reference

**[← Back to SKILL.md](../SKILL.md)**

## How Sub-Issues Create Relationships

GitHub's sub-issues API creates parent-child relationships between issues using GraphQL mutations.

### Creating Relationships

Use the `addSubIssue` mutation to link a child issue to a parent:

```graphql
mutation {
  addSubIssue(input: {
    issueId: "I_parent_node_id"
    subIssueId: "I_child_node_id"
  }) {
    issue { id number }
    subIssue { id number }
  }
}
```

**Important:** Sub-issues queries require the `GraphQL-Features: sub_issues` header:
```bash
gh api graphql -H "GraphQL-Features: sub_issues" -f query='...'
```

### What GitHub Creates

- Parent gets `subIssues: [child1, child2]`
- Children get `parentIssue: parentIssue`
- Relationships are immediate (no async parsing delay)

### API Limits

GitHub's sub-issues API has the following limits:
- **Maximum sub-issues per parent:** 100
- **Maximum nesting depth:** 8 levels
- Exceeding these limits will result in silent failures or API errors

For hierarchies with more than 100 direct children, consider splitting into multiple Features. For deeply nested structures beyond 8 levels, flatten the hierarchy or use alternative organization methods.

---

## Creating Relationships

### Step 1: Create Children First

```graphql
mutation {
  createIssue(input: {
    repositoryId: "R_xxx"
    title: "Feature: Script Conversion"
    issueTypeId: "IT_feature"
  }) {
    issue { id number }
  }
}
```

### Step 2: Link Children to Parent

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

### Step 3: Verify

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      subIssues(first: 50) {
        nodes {
          number
          issueType { name }
          title
        }
      }
      parentIssue {
        number
        title
      }
    }
  }
}
```

**Note:** Remember to include the `GraphQL-Features: sub_issues` header in all sub-issues queries.

---

## Advanced Queries

### Full Issue Relationships (Parents + Children)

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 106) {
      title
      issueType { name }
      subIssues(first: 50) {
        totalCount
        nodes { number title issueType { name } state }
      }
      parentIssue {
        number
        title
        issueType { name }
      }
    }
  }
}
```

### Nested Hierarchy (Epic → Features → Tasks)

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      title
      issueType { name }
      subIssues(first: 50) {
        nodes {
          number
          title
          issueType { name }
          subIssues(first: 50) {
            nodes {
              number
              title
              issueType { name }
            }
          }
        }
      }
    }
  }
}
```

### Find Orphaned Issues (No Parent)

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issues(first: 100, filterBy: { states: OPEN }) {
      nodes {
        number
        title
        issueType { name }
        parentIssue {
          number
        }
      }
    }
  }
}
```

Filter in PowerShell: `Where-Object { -not $_.parentIssue }`

### Completion Status

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      title
      subIssues(first: 100) {
        totalCount
        nodes { number state closed }
      }
    }
  }
}
```

Calculate: `closedCount / totalCount * 100` for percentage.

---

## Removing Relationships

### Unlink a Child from Parent

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

## Dependency Relationships (Blocks/Blocked-By)

In addition to parent-child hierarchy, issues can have dependency relationships independent of the tree structure. These are tracked via cross-references in issue bodies and comments.

### Why Use Dependencies?

- **Cross-cutting concerns:** Task A depends on Task B, but they're in different Features
- **Sequential work:** One task must complete before another can start
- **DAG readiness:** Determine which issues are ready to work on

### Creating Dependencies with Set-IssueDependency.ps1

```powershell
# Mark issue 22 as blocked by issues 4 and 53
.\Set-IssueDependency.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 22 -BlockedBy 4,53

# Mark issue 4 as blocking issue 22
.\Set-IssueDependency.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 4 -Blocks 22

# Query dependencies for an issue
.\Set-IssueDependency.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 22 -Action Query
```

### How It Works

The script adds a comment to the issue with structured markers:

```markdown
**Blocked by** #4, #53 — **Blocks** #22
```

These markers are parsed by DAG readiness scripts to determine:
- Which issues can't start yet (blocked by open issues)
- Which issues are ready to work on (no open blockers)
- Which issues will unblock others when completed

### Dependency Patterns

The parser recognizes these patterns (case-insensitive):

- `Blocked by #N` or `Blocked by: #N`
- `Blocks #N` or `Blocks: #N`
- `Depends on #N` (equivalent to "Blocked by")
- Cross-repo: `Blocked by anokye-labs/repo#N`

### Manual Dependency Management

You can also add dependencies manually in issue bodies or comments:

```markdown
## Dependencies

**Blocked by #4** — Requires Invoke-GraphQL.ps1 foundation layer.

**Blocked by #53** — CI validation pipeline must be in place.
```

### Removing Dependencies

Dependencies are removed by editing the issue body or deleting the comment containing the marker. This is intentionally manual to ensure human review and maintain DAG consistency.

```powershell
# Remove action warns and instructs manual edit
.\Set-IssueDependency.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 22 -Action Remove
```

### Integration with DAG Readiness

Dependency relationships integrate with existing DAG scripts:

- **Get-BlockedIssues.ps1** — Finds issues with open blockers
- **Get-ReadyIssues.ps1** — Finds issues ready to work on
- **Get-DagStatus.ps1** — Shows overall DAG health

An issue is considered "ready" when:
1. All child sub-issues are closed
2. No open issues are referenced as blockers

---

## Conventions

| Parent Type | Children |
|-------------|----------|
| Epic (with Features) | Feature issues |
| Epic (direct Tasks) | Task issues |
| Feature | Task issues |
| Task | *(none — leaf node)* |

**Never mix Features and Tasks** as direct children of the same Epic. Choose one pattern.

**[← Back to SKILL.md](../SKILL.md)**
