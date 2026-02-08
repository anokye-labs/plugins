# Evaluation 2: Issue Type Discovery

**Priority:** 🔴 Critical  
**Time:** 5 minutes  
**Prerequisites:** Installed plugin, GitHub CLI authenticated, org with issue types

## Objective

Verify the plugin can discover organization issue types and return usable type IDs.

## Test Steps

### 2.1 Get Issue Type IDs

**Action:** Run the type discovery script.

```powershell
& .github\skills\okyerema\scripts\Get-IssueTypeIds.ps1 -Owner anokye-labs
```

**Expected:**
- [ ] Returns a hashtable with at least 4 entries
- [ ] Contains: Epic, Feature, Task, Bug
- [ ] Each value is an `IT_xxx` format ID
- [ ] No errors or warnings

### 2.2 Type IDs Are Valid

**Action:** Verify a type ID works in a query.

```powershell
$types = & .github\skills\okyerema\scripts\Get-IssueTypeIds.ps1 -Owner anokye-labs
$featureId = $types['Feature']
Write-Host "Feature ID: $featureId"
# Verify format
$featureId -match '^IT_'
```

**Expected:**
- [ ] Feature ID starts with `IT_`
- [ ] ID is a non-empty string

### 2.3 Unknown Org Handling

**Action:** Try with a non-existent organization.

```powershell
$result = & .github\skills\okyerema\scripts\Get-IssueTypeIds.ps1 -Owner "nonexistent-org-12345" 2>&1
```

**Expected:**
- [ ] Script handles error gracefully
- [ ] Error message is descriptive

### 2.4 Copilot Can Use Skill

**Action:** In a Copilot chat session, ask:

> "What are the issue type IDs for the anokye-labs organization?"

**Expected:**
- [ ] Copilot references the okyerema skill
- [ ] Runs or references `Get-IssueTypeIds.ps1`
- [ ] Returns the correct type IDs

## Pass/Fail

- **PASS:** Steps 2.1, 2.2, and 2.4 succeed
- **FAIL:** Any of these fail
