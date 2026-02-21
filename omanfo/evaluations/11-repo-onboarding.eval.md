# Evaluation 11: Repo Onboarding Audit

**Priority:** 🟡 High  
**Time:** 15 minutes  
**Prerequisites:** Installed plugin, GitHub CLI authenticated, PowerShell 7+, access to a test repository

## Objective

Validate the end-to-end repo onboarding flow: audit readiness, identify gaps,
generate issues for missing pieces, and verify the template copilot-instructions.

## Scenario

A new repository `anokye-labs/test-onboarding-eval` is created with no
automation infrastructure. Okyerema should detect all gaps and scaffold
the missing pieces via GitHub issues.

## Setup

```powershell
# Use any accessible test repository or create a minimal one
$testOwner = "anokye-labs"
$testRepo  = "plugins"   # use plugins as a fully-configured reference
```

## Test Steps

### 11.1 Run Readiness Audit

**Action:**

```powershell
& .github\skills\okyerema\scripts\Get-RepoReadiness.ps1 -Owner anokye-labs -Repo plugins
```

**Expected:**
- [ ] Script completes without errors
- [ ] Returns a `PSCustomObject` with `ReadinessScore`, `Gaps`, and all check properties
- [ ] Score ≥ 50 for a configured repo like `plugins`
- [ ] Each check property (`CopilotInstructionsOk`, `AgenticWorkflowsOk`, etc.) is a Boolean

### 11.2 Brief Output Mode

**Action:**

```powershell
& .github\skills\okyerema\scripts\Get-RepoReadiness.ps1 -Owner anokye-labs -Repo plugins -Brief
```

**Expected:**
- [ ] Single-line output with emoji icon, score, and gap count
- [ ] Format: `✅/⚠️/🔴 owner/repo readiness: N/100 | N gap(s): ...`

### 11.3 Readiness Score Interpretation

**Action:** In Copilot chat:

> "Run the repo readiness check on anokye-labs/plugins and explain what each gap means."

**Expected:**
- [ ] Copilot invokes `Get-RepoReadiness.ps1`
- [ ] Explains each gap in plain language
- [ ] References `agentic-workflows.md` for context on missing pieces
- [ ] Suggests running `Initialize-RepoAutomation.ps1` to create issues

### 11.4 WhatIf Preview

**Action:**

```powershell
& .github\skills\okyerema\scripts\Initialize-RepoAutomation.ps1 `
    -Owner anokye-labs -Repo plugins -WhatIf
```

**Expected:**
- [ ] Script shows `[WhatIf]` preview lines for each gap
- [ ] No issues are actually created
- [ ] Script exits cleanly

### 11.5 Issue Generation (Isolated Test)

**Action:** Create a fresh report with a synthetic gap list and run initialize:

```powershell
# Simulate a repo missing copilot-instructions only
$report = [PSCustomObject]@{
    Owner                   = "anokye-labs"
    Repo                    = "plugins"
    ReadinessScore          = 75
    Gaps                    = @("CopilotInstructions")
    GapCount                = 1
    CopilotInstructionsOk   = $false
    CopilotInstructionsNote = "missing"
    AgenticWorkflowsOk      = $true
    AgenticWorkflowsNote    = "present"
    AgenticWorkflowCount    = 2
    ProjectLinkedOk         = $true
    ProjectLinkedNote       = "1 active project"
    ActiveProjects          = @()
    IssueTypesOk            = $true
    IssueTypesNote          = "in use"
    CiWorkflowsOk           = $true
    CiWorkflowsNote         = "present"
    CiWorkflowCount         = 3
}

# Preview only — do not actually create issues in eval
& .github\skills\okyerema\scripts\Initialize-RepoAutomation.ps1 `
    -Owner anokye-labs -Repo plugins `
    -ReadinessReport $report -WhatIf
```

**Expected:**
- [ ] Shows `[WhatIf] Would create Epic: 'Repo Automation Onboarding: anokye-labs/plugins'`
- [ ] Shows `[WhatIf] Would create Task: 'Add .github/copilot-instructions.md'`
- [ ] Exits cleanly

### 11.6 Copilot-Instructions Template

**Action:**

```powershell
Test-Path ".github\skills\okyerema\templates\copilot-instructions.md"
$template = Get-Content ".github\skills\okyerema\templates\copilot-instructions.md" -Raw
$template.Length | Should -BeGreaterThan 1000
```

**Expected:**
- [ ] Template file exists at `templates/copilot-instructions.md`
- [ ] File is >1000 characters
- [ ] Contains sections: Repository Overview, Anokye System Rules, Tech Stack Conventions, Coding Conventions, Agent Behaviour Rules

### 11.7 Context Integration (Agent Mode)

**Action:** In Copilot chat:

> "What is the readiness status of this repository? Are there any automation gaps?"

**Expected:**
- [ ] Copilot mentions `Get-RepoReadiness.ps1` or the `/readiness` command
- [ ] Provides a concrete answer about the current repo's status
- [ ] If gaps exist, proposes `Initialize-RepoAutomation.ps1` to address them

### 11.8 Full Pipeline (Optional, Creates Issues)

> ⚠️ This step creates real GitHub issues. Skip in automated eval runs.

**Action:**

```powershell
& .github\skills\okyerema\scripts\Initialize-RepoAutomation.ps1 `
    -Owner anokye-labs -Repo plugins
```

**Expected:**
- [ ] Creates one Epic with title "Repo Automation Onboarding: anokye-labs/plugins"
- [ ] Creates one Task per gap found
- [ ] Tasks are linked as sub-issues of the Epic
- [ ] Each Task has a well-formed body with acceptance criteria
- [ ] Tasks assigned to `@copilot` (if Copilot App installed in org)

## Cleanup

```powershell
# Close any issues created during 11.8
gh issue list -R "anokye-labs/plugins" --search "Repo Automation Onboarding" --json number |
    ConvertFrom-Json | ForEach-Object { gh issue close $_.number -R "anokye-labs/plugins" }
```

## Scoring

| Step | Area | Weight |
|------|------|--------|
| 11.1 | Readiness audit runs cleanly | 20% |
| 11.2 | Brief output mode | 10% |
| 11.3 | Agent explains gaps | 15% |
| 11.4 | WhatIf preview | 15% |
| 11.5 | Issue generation from report | 20% |
| 11.6 | Template file exists and is complete | 10% |
| 11.7 | Context integration | 10% |

## Pass/Fail

- **PASS:** Score ≥ 75% (steps 11.1, 11.4, 11.5 all succeed + at least 2 of 11.2, 11.3, 11.6, 11.7)
- **FAIL:** Score < 75% or any of steps 11.1, 11.4, 11.5 fail
