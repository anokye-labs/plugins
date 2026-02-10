# Plan Materialization

Convert markdown plan documents into GitHub issue DAGs with proper hierarchy.

## Overview

The plan materialization pipeline allows you to author project plans in markdown and automatically convert them into structured GitHub issues with Epic→Feature→Task hierarchy. This bridges the gap between high-level planning documents and actionable work items.

## When to Use

- **Initial project setup** — Convert a roadmap document into issues
- **Feature planning** — Break down a feature spec into a DAG of tasks
- **Sprint planning** — Transform a sprint plan into trackable work items
- **Documentation-first workflow** — Write the plan in markdown, then materialize it

## How It Works

### Markdown to Issue Type Mapping

The pipeline uses heading levels to determine issue types:

- **H1 (#)** → Epic
- **H2 (##)** → Feature
- **H3 (###)** → Task

Content following a heading becomes the issue body. The heading text becomes the issue title.

### Hierarchy Patterns

**Pattern A: Epic → Feature → Task**

```markdown
# Phase 2: Advanced Features

This epic covers the implementation of advanced features.

## User Authentication

Implement OAuth2 and JWT-based authentication.

### Setup OAuth2 Provider

Configure OAuth2 provider integration (Google, GitHub).

### Implement JWT Token Management

Create JWT token generation, validation, and refresh logic.
```

Creates:
```
Epic #14: Phase 2: Advanced Features
├─ Feature #15: User Authentication
│  ├─ Task #16: Setup OAuth2 Provider
│  └─ Task #17: Implement JWT Token Management
```

**Pattern B: Epic → Task** (when tasks don't group into features)

```markdown
# Phase 0: Setup

Initial project setup tasks.

### Initialize Repository

Create repo structure and .gitignore.

### Configure CI/CD

Set up GitHub Actions workflows.
```

Creates:
```
Epic #1: Phase 0: Setup
├─ Task #2: Initialize Repository
└─ Task #3: Configure CI/CD
```

**Pattern C: Feature → Task** (standalone feature)

```markdown
## Notification System

Build a real-time notification system.

### Design Notification Schema

Define database schema for notifications.

### Implement Push Notifications

Add push notification support using WebSockets.
```

Creates:
```
Feature #20: Notification System
├─ Task #21: Design Notification Schema
└─ Task #22: Implement Push Notifications
```

## Usage

### Invoke-PlanMaterialization.ps1

Converts a markdown plan into GitHub issues (one-time operation).

```powershell
# Basic usage
./Invoke-PlanMaterialization.ps1 `
  -Owner "anokye-labs" `
  -Repo "my-project" `
  -PlanFile "./roadmap.md"

# Preview what would be created
./Invoke-PlanMaterialization.ps1 `
  -Owner "anokye-labs" `
  -Repo "my-project" `
  -PlanFile "./roadmap.md" `
  -DryRun

# Save mapping for later sync
./Invoke-PlanMaterialization.ps1 `
  -Owner "anokye-labs" `
  -Repo "my-project" `
  -PlanFile "./roadmap.md" `
  -MappingFile "./roadmap-mapping.json"
```

**Output:**
- Creates issues with proper organization types (Epic/Feature/Task)
- Builds parent-child relationships using sub-issues API
- Generates a mapping file (`.json`) linking plan items to issue numbers
- Preserves issue body content from markdown

### Sync-PlanToIssues.ps1

Syncs an updated markdown plan with existing issues (incremental updates).

```powershell
# Sync changes from updated plan
./Sync-PlanToIssues.ps1 `
  -Owner "anokye-labs" `
  -Repo "my-project" `
  -PlanFile "./roadmap.md" `
  -MappingFile "./roadmap-mapping.json"

# Preview what would change
./Sync-PlanToIssues.ps1 `
  -Owner "anokye-labs" `
  -Repo "my-project" `
  -PlanFile "./roadmap.md" `
  -MappingFile "./roadmap-mapping.json" `
  -DryRun
```

**What Gets Synced:**
- ✅ Issue body updates (when description changes in markdown)
- ✅ New items detection (reports items to create manually)
- ⚠️ Does NOT update titles (issues are identified by title+type)
- ⚠️ Does NOT delete issues (manual cleanup required)

## Workflow

### Initial Materialization

1. Write your plan in markdown
2. Run `Invoke-PlanMaterialization.ps1` to create issues
3. Save the mapping file for future syncs

### Iterative Updates

1. Update the markdown plan
2. Run `Sync-PlanToIssues.ps1` to sync changes
3. Review the diff and apply updates

### Best Practices

**Do:**
- ✅ Keep plan files under version control
- ✅ Use consistent heading structure (don't skip levels)
- ✅ Add descriptive body content for context
- ✅ Run with `-DryRun` first to preview changes
- ✅ Keep mapping files alongside plan files

**Don't:**
- ❌ Rename issue titles after creation (breaks mapping)
- ❌ Mix heading levels (e.g., H1 → H3 without H2)
- ❌ Use heading levels beyond H3 (no issue type for H4+)
- ❌ Delete mapping files (needed for sync operations)

## Limitations

### Not Yet Supported

- **Project assignment** — Issues aren't automatically added to projects (manual step)
- **Label application** — No label support in current version
- **Issue deletion** — Removed plan items don't delete issues
- **Title updates** — Changing titles breaks the mapping
- **Complex hierarchies** — No support for H4/H5 (max 3 levels)
- **Task lists** — Checkbox lists are not parsed as sub-issues

### Workarounds

**Project assignment:** Use `gh project item-add` after materialization
```bash
gh project item-add 1 --owner anokye-labs --url https://github.com/anokye-labs/my-project/issues/14
```

**Labels:** Use `gh issue edit` or GraphQL after materialization
```bash
gh issue edit 14 --add-label "priority:high,component:api"
```

## Examples

### Example: Feature Roadmap

**Input:** `roadmap.md`
```markdown
# Q1 2025 Roadmap

## API v2 Launch

### Update OpenAPI Spec

### Implement Versioning

### Write Migration Guide

## Mobile App

### iOS App

### Android App
```

**Command:**
```powershell
./Invoke-PlanMaterialization.ps1 -Owner "acme" -Repo "platform" -PlanFile "./roadmap.md"
```

**Output:**
```
✓ Created #42 [Epic] Q1 2025 Roadmap
✓ Created #43 [Feature] API v2 Launch
✓ Created #44 [Task] Update OpenAPI Spec
✓ Created #45 [Task] Implement Versioning
✓ Created #46 [Task] Write Migration Guide
✓ Linked #42 → #43
✓ Linked #43 → #44
✓ Linked #43 → #45
✓ Linked #43 → #46
✓ Created #47 [Feature] Mobile App
✓ Created #48 [Task] iOS App
✓ Created #49 [Task] Android App
✓ Linked #42 → #47
✓ Linked #47 → #48
✓ Linked #47 → #49

Created 8 issues from plan
✓ Saved mapping to ./roadmap.md-mapping.json
```

## Troubleshooting

### "Issue type 'Epic' not found"

Organization issue types not configured. Ensure your organization has Epic, Feature, and Task types defined.

**Solution:** Contact your organization admin to set up issue types, or use [scripts/New-IssueWithType.ps1](../scripts/New-IssueWithType.ps1) to verify available types.

### "Failed to link issues"

Sub-issues API requires GraphQL-Features header. The scripts handle this automatically, but if you see this error, GitHub may be having issues.

**Solution:** Retry the operation. The script creates issues successfully even if linking fails — you can manually add relationships later.

### "Mapping file not found"

The sync script requires a mapping file created by the materialization script.

**Solution:** Run `Invoke-PlanMaterialization.ps1` first to create the mapping file, or check the file path.

## See Also

- [Issue Types](issue-types.md) — Creating and managing organization issue types
- [Relationships](relationships.md) — Parent-child hierarchy and sub-issues API
- [New-IssueWithType.ps1](../scripts/New-IssueWithType.ps1) — Create single issues with types
- [Update-IssueHierarchy.ps1](../scripts/Update-IssueHierarchy.ps1) — Build parent-child relationships
