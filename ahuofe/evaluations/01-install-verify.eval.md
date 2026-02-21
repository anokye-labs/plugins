# Evaluation 1: Installation & Verification

**Priority:** 🔴 Critical  
**Time:** 5 minutes  
**Prerequisites:** Target test repository, PowerShell 7+

## Objective

Verify the Ahuofe plugin installs correctly and all skill files are present in the target repository.

## Setup

Create or use an existing test repository:

```powershell
$testRepo = "C:\temp\test-ahuofe-eval"
mkdir $testRepo -Force
cd $testRepo
git init
```

## Test Steps

### 1.1 Fresh Install

**Action:** Run the installation script.

```powershell
& <plugins-root>\ahuofe\scripts\Install-Ahuofe.ps1 -TargetRepo $testRepo -Force
```

**Expected:**
- [ ] Script completes without errors
- [ ] Output shows ✅ for each installed file
- [ ] Next steps are displayed

### 1.2 Skill Structure Verification

**Action:** Check installed skill directories.

```powershell
$skills = @("fal-ai", "fal-workflow", "image-sorcery", "media-agents")
foreach ($skill in $skills) {
    $path = "$testRepo\.github\skills\$skill\SKILL.md"
    Write-Host "$skill : $(Test-Path $path)"
}
```

**Expected:**
- [ ] All 4 skills return `True`
- [ ] Each skill directory contains `SKILL.md`
- [ ] Skills with references have a `references/` subdirectory

### 1.3 Scripts Installed

**Action:** Check that shared scripts are deployed.

```powershell
Test-Path "$testRepo\.github\skills\ahuofe-scripts\FalAi.psm1"
(Get-ChildItem "$testRepo\.github\skills\ahuofe-scripts" -Filter "*.ps1").Count
```

**Expected:**
- [ ] `FalAi.psm1` exists
- [ ] At least 14 `.ps1` scripts present

### 1.4 Skip Scripts Option

**Action:** Reinstall with `-SkipScripts`.

```powershell
Remove-Item "$testRepo\.github\skills\ahuofe-scripts" -Recurse -Force -ErrorAction SilentlyContinue
& <plugins-root>\ahuofe\scripts\Install-Ahuofe.ps1 -TargetRepo $testRepo -SkipScripts -Force
```

**Expected:**
- [ ] Skill files are installed
- [ ] `ahuofe-scripts/` directory is NOT created

### 1.5 Root Installer Works

**Action:** Test via the root Install-Plugins.ps1.

```powershell
& <plugins-root>\Install-Plugins.ps1 -TargetRepo $testRepo -Plugins ahuofe -Force
```

**Expected:**
- [ ] Discovers ahuofe plugin from plugin.json
- [ ] Delegates to Install-Ahuofe.ps1
- [ ] Reports 1 plugin installed

## Cleanup

```powershell
Remove-Item $testRepo -Recurse -Force
```

## Pass/Fail

- **PASS:** Steps 1.1, 1.2, 1.3, and 1.5 succeed
- **FAIL:** Any of these fail
