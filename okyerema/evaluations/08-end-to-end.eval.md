# Evaluation 8: End-to-End Workflow

**Priority:** 🔴 Critical  
**Time:** 20 minutes  
**Prerequisites:** Installed plugin, full environment (GitHub CLI, org access, PowerShell 7+)

## Objective

Validate a complete project planning workflow from scratch — the full orchestration cycle that Okyerema is designed for.

## Scenario

A team wants to plan a new feature "User Notifications" with:
- 1 Epic for the initiative
- 2 Features (Email notifications, In-app notifications)
- 3 Tasks per feature (6 total)
- Issues added to a project board

## Test Steps

### 8.1 Discovery Phase

**Action:** In Copilot chat:

> "I need to plan a new initiative called 'User Notifications' in anokye-labs/plugins. What issue types are available and what hierarchy should I use?"

**Expected:**
- [ ] Copilot references okyerema skill
- [ ] Recommends Epic → Feature → Task hierarchy
- [ ] Shows available issue types
- [ ] Suggests a plan structure

### 8.2 Create the Epic

**Action:** In Copilot chat:

> "Create an Epic issue titled 'User Notifications' with a description outlining email and in-app notification features."

**Expected:**
- [ ] Epic is created with correct type
- [ ] Description is well-formatted
- [ ] Returns issue number

### 8.3 Create Features Under Epic

**Action:** In Copilot chat:

> "Create two Feature issues: 'Email Notifications' and 'In-App Notifications'. Link them as children of the User Notifications Epic."

**Expected:**
- [ ] Both features created with Feature type
- [ ] Epic body updated with tasklist containing both features
- [ ] Hierarchy is established (may need to wait for GitHub parsing)

### 8.4 Create Tasks Under Features

**Action:** In Copilot chat:

> "For 'Email Notifications', create tasks: 'Design email templates', 'Implement SMTP integration', 'Write email notification tests'. Link them to the feature."

**Expected:**
- [ ] 3 tasks created with Task type
- [ ] Feature body updated with tasklist
- [ ] Tasks are linked to the feature

### 8.5 Verify Full Hierarchy

**Action:** In Copilot chat:

> "Show me the complete hierarchy tree starting from the User Notifications Epic."

**Expected:**
- [ ] 3-level tree displayed: Epic → 2 Features → 3 Tasks each
- [ ] All issue numbers and titles correct
- [ ] States shown (all should be Open)
- [ ] Types displayed

### 8.6 Project Board Integration

**Action:** In Copilot chat:

> "Add all User Notifications issues to the Media Plugin Development project board."

**Expected:**
- [ ] Epic + Features + Tasks all added to project
- [ ] No errors about duplicate items
- [ ] Issues visible on project board

### 8.7 Error Recovery

**Action:** Deliberately cause an error and verify recovery.

```powershell
# Try to create an issue with an invalid type
& .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner "anokye-labs" -Repo "plugins" `
    -Title "Error Test" -TypeName "InvalidType" -Body "Should fail."
```

**Expected:**
- [ ] Error is descriptive (references errors.md guide)
- [ ] Does not crash or leave partial state
- [ ] Suggests valid type names

### 8.8 Copilot Uses Error Reference

**Action:** In Copilot chat:

> "I got an error 'Could not resolve to a node' when trying to create an issue. What does this mean?"

**Expected:**
- [ ] Copilot references errors.md
- [ ] Explains the error (stale type ID, wrong repo ID, etc.)
- [ ] Suggests fix steps

### 8.9 PR Review Workflow

**Action:** If a PR exists, test the full review cycle in Copilot:

> "Check PR #6 in anokye-labs/akwaaba for unresolved review threads. Summarize them."

**Expected:**
- [ ] Lists all unresolved threads with file paths and comments
- [ ] Can follow up with replies or resolutions

### 8.10 Glossary Knowledge

**Action:** In Copilot chat:

> "What does 'Okyerema' mean? What about 'Asafo' and 'Adwoma'?"

**Expected:**
- [ ] Copilot references the glossary
- [ ] Correctly explains: Okyerema = drummer/coordinator, Asafo = team/company, Adwoma = work
- [ ] May reference the how-we-work documentation

## Cleanup

```powershell
# Close all User Notifications eval issues
gh issue list -R "anokye-labs/plugins" --search "User Notifications" --json number | 
    ConvertFrom-Json | ForEach-Object { gh issue close $_.number -R "anokye-labs/plugins" }
gh issue list -R "anokye-labs/plugins" --search "Email Notifications" --json number | 
    ConvertFrom-Json | ForEach-Object { gh issue close $_.number -R "anokye-labs/plugins" }
gh issue list -R "anokye-labs/plugins" --search "In-App Notifications" --json number | 
    ConvertFrom-Json | ForEach-Object { gh issue close $_.number -R "anokye-labs/plugins" }
```

## Scoring

| Step | Area | Weight |
|------|------|--------|
| 8.1 | Skill discovery | 10% |
| 8.2 | Issue creation | 10% |
| 8.3 | Feature linking | 15% |
| 8.4 | Task linking | 15% |
| 8.5 | Hierarchy verification | 15% |
| 8.6 | Project integration | 10% |
| 8.7 | Error handling | 10% |
| 8.8 | Error reference | 5% |
| 8.9 | PR reviews | 5% |
| 8.10 | Documentation | 5% |

## Pass/Fail

- **PASS:** Score ≥ 75% (steps 8.1-8.5 all succeed + at least 2 of 8.6-8.10)
- **FAIL:** Score < 75% or any of steps 8.2-8.5 fail
