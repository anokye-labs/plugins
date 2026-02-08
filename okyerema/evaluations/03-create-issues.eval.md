# Evaluation 3: Creating Typed Issues

**Priority:** 🔴 Critical  
**Time:** 10 minutes  
**Prerequisites:** Installed plugin, GitHub CLI authenticated, org issue type IDs known

## Objective

Verify the plugin can create issues with proper organization types via GraphQL.

## Setup

Use a test repository that you can create/delete issues in.

```powershell
$owner = "anokye-labs"
$repo = "plugins"  # or a dedicated test repo
```

## Test Steps

### 3.1 Create a Task Issue

**Action:** Create a simple Task issue.

```powershell
& .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner $owner -Repo $repo `
    -Title "Eval 3.1: Test Task Creation" `
    -TypeName "Task" `
    -Body "Created by plugin evaluation. Safe to delete."
```

**Expected:**
- [ ] Issue is created successfully
- [ ] Returns issue number and URL
- [ ] Issue type shows as "Task" in GitHub UI
- [ ] Body text is preserved correctly

### 3.2 Create a Feature Issue

**Action:** Create a Feature issue with labels.

```powershell
& .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner $owner -Repo $repo `
    -Title "Eval 3.2: Test Feature Creation" `
    -TypeName "Feature" `
    -Body "Feature with labels test." `
    -Labels @("evaluation")
```

**Expected:**
- [ ] Issue type shows as "Feature"
- [ ] Label "evaluation" is applied (if it exists)
- [ ] If label doesn't exist, graceful handling

### 3.3 Special Characters in Title

**Action:** Create an issue with special characters.

```powershell
& .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner $owner -Repo $repo `
    -Title 'Eval 3.3: Special chars "quotes" & backslash \ test' `
    -TypeName "Bug" `
    -Body "Testing escape handling."
```

**Expected:**
- [ ] Issue is created without GraphQL errors
- [ ] Title preserves quotes and backslashes
- [ ] Body is correct

### 3.4 Multiline Body

**Action:** Create an issue with a multiline body.

```powershell
$body = @"
## Description

This is a multiline body test.

### Acceptance Criteria

- [ ] First criterion
- [ ] Second criterion

### Notes

Contains ``code blocks`` and **formatting**.
"@

& .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner $owner -Repo $repo `
    -Title "Eval 3.4: Multiline Body Test" `
    -TypeName "Task" `
    -Body $body
```

**Expected:**
- [ ] Markdown renders correctly in GitHub UI
- [ ] Checkboxes are functional
- [ ] Code formatting preserved

### 3.5 Copilot Creates Issue via Skill

**Action:** In a Copilot chat session, ask:

> "Create a Bug issue in anokye-labs/plugins titled 'Eval 3.5: Copilot-created issue' with body 'Created by Copilot using okyerema skill.'"

**Expected:**
- [ ] Copilot uses the okyerema skill
- [ ] Issue is created with correct type
- [ ] Returns the issue URL

## Cleanup

Delete all evaluation issues:

```powershell
# List eval issues
gh issue list -R "$owner/$repo" --search "Eval 3." --json number,title
# Close them
gh issue close <number> -R "$owner/$repo"
```

## Pass/Fail

- **PASS:** Steps 3.1, 3.3, 3.4, and 3.5 succeed
- **FAIL:** Any of these fail (3.2 may warn if labels don't exist)
