# Evaluation 1: Installation & Verification

**Priority:** 🔴 Critical  
**Time:** 5 minutes  
**Prerequisites:** Target test repository, PowerShell 7+

## Objective

Verify the plugin installs correctly and all files are present in the target repository.

## Setup

Create or use an existing test repository:

```powershell
$testRepo = "S:\anokye-labs\test-omanfo-eval"
mkdir $testRepo -Force
cd $testRepo
git init
```

## Test Steps

### 1.1 Fresh Install

**Action:** Run the installation script.

```powershell
& S:\anokye-labs\plugins\omanfo\scripts\Install-Plugin.ps1 -TargetRepo $testRepo -Force
```

**Expected:**
- [ ] Script completes without errors
- [ ] Output shows ✅ for each installed file
- [ ] Next steps are displayed

### 1.2 File Structure Verification

**Action:** Check installed files.

```powershell
Get-ChildItem -Path "$testRepo\.github\skills\okyerema" -Recurse -File | Select-Object Name
```

**Expected files (14 total):**
- [ ] `SKILL.md`
- [ ] `references/issue-types.md`
- [ ] `references/relationships.md`
- [ ] `references/projects.md`
- [ ] `references/pr-reviews.md`
- [ ] `references/labels.md`
- [ ] `references/errors.md`
- [ ] `scripts/Get-IssueTypeIds.ps1`
- [ ] `scripts/New-IssueWithType.ps1`
- [ ] `scripts/Update-IssueHierarchy.ps1`
- [ ] `scripts/Test-Hierarchy.ps1`
- [ ] `scripts/Get-UnresolvedThreads.ps1`
- [ ] `scripts/Reply-ReviewThread.ps1`
- [ ] `scripts/Resolve-ReviewThreads.ps1`

### 1.3 Documentation Installed

**Action:** Check documentation files.

```powershell
Test-Path "$testRepo\how-we-work.md"
Test-Path "$testRepo\how-we-work\getting-started.md"
Test-Path "$testRepo\agents.md"
```

**Expected:**
- [ ] All return `True`

### 1.4 Skip Options Work

**Action:** Reinstall with skip flags.

```powershell
Remove-Item "$testRepo\how-we-work.md" -Force
Remove-Item "$testRepo\agents.md" -Force
& S:\anokye-labs\plugins\omanfo\scripts\Install-Plugin.ps1 -TargetRepo $testRepo -SkipDocs -SkipAgents -Force
```

**Expected:**
- [ ] Skill files are installed
- [ ] `how-we-work.md` is NOT created
- [ ] `agents.md` is NOT created

### 1.5 Verification Script

**Action:** Run the verification script.

```powershell
& S:\anokye-labs\plugins\omanfo\scripts\Verify-Installation.ps1 -TargetRepo $testRepo -Owner anokye-labs
```

**Expected:**
- [ ] All required checks pass (✅)
- [ ] Documentation checks show ⚠️ (if skipped)
- [ ] Prerequisites all pass
- [ ] Skill quality checks pass

### 1.6 SKILL.md Quality

**Action:** Verify skill file meets standards.

```powershell
$skill = Get-Content "$testRepo\.github\skills\okyerema\SKILL.md"
Write-Host "Lines: $($skill.Count)"
Write-Host "Has frontmatter: $($skill[0] -eq '---')"
```

**Expected:**
- [ ] Under 500 lines
- [ ] Has YAML frontmatter
- [ ] Contains description field

## Cleanup

```powershell
Remove-Item $testRepo -Recurse -Force
```

## Pass/Fail

- **PASS:** All critical checks (1.1, 1.2, 1.5) succeed
- **FAIL:** Any critical check fails
