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
- Children get `parent: parentIssue`
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
      parent {
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
      parent {
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
        parent {
          number
        }
      }
    }
  }
}
```

Filter in PowerShell: `Where-Object { -not $_.parent }`

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

## Conventions

| Parent Type | Children |
|-------------|----------|
| Epic (with Features) | Feature issues |
| Epic (direct Tasks) | Task issues |
| Feature | Task issues |
| Task | *(none — leaf node)* |

**Never mix Features and Tasks** as direct children of the same Epic. Choose one pattern.

**[← Back to SKILL.md](../SKILL.md)**
