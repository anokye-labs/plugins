<#
.SYNOPSIS
    Generate GitHub issues for each missing automation infrastructure piece.

.DESCRIPTION
    Reads the output of Get-RepoReadiness.ps1 (or runs it inline) and creates
    well-specified GitHub issues for every readiness gap found in the target
    repository. Optionally assigns issues to @copilot for automated resolution.

    Issues created (for each gap):
    - Missing copilot-instructions.md → Task: "Add .github/copilot-instructions.md"
    - Missing agentic workflows → Task: "Add agentic workflows to .github/aw/"
    - No GitHub Project linked → Task: "Create and link GitHub Project board"
    - Issue types not in use → Task: "Adopt organization issue types"
    - No CI/CD workflows → Task: "Configure CI/CD workflows"

    All tasks are created under an Epic: "Repo Automation Onboarding" unless
    a parent issue number is provided.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER ReadinessReport
    Pre-computed readiness report from Get-RepoReadiness.ps1. If omitted, the
    script runs Get-RepoReadiness.ps1 from the same directory.

.PARAMETER ParentIssueNumber
    Existing issue number to use as Epic parent. If omitted, a new Epic is created.

.PARAMETER WhatIf
    Preview what issues would be created without creating them.

.EXAMPLE
    .\Initialize-RepoAutomation.ps1 -Owner anokye-labs -Repo my-repo

.EXAMPLE
    $report = .\Get-RepoReadiness.ps1 -Owner anokye-labs -Repo my-repo
    .\Initialize-RepoAutomation.ps1 -Owner anokye-labs -Repo my-repo -ReadinessReport $report

.EXAMPLE
    .\Initialize-RepoAutomation.ps1 -Owner anokye-labs -Repo my-repo -WhatIf
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [PSCustomObject]$ReadinessReport,
    [int]$ParentIssueNumber,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"
. "$PSScriptRoot\_Get-RepoContext.ps1"

# --- Run readiness check if not provided ---

if (-not $ReadinessReport) {
    $scriptDir = $PSScriptRoot
    $readinessScript = Join-Path $scriptDir "Get-RepoReadiness.ps1"
    if (-not (Test-Path $readinessScript)) {
        Write-Error "Get-RepoReadiness.ps1 not found at: $readinessScript"
        return
    }
    Write-Host "🔍 Running readiness audit for $Owner/$Repo..." -ForegroundColor Cyan
    $ReadinessReport = & $readinessScript -Owner $Owner -Repo $Repo
}

if (-not $ReadinessReport) {
    Write-Error "Failed to obtain readiness report."
    return
}

if ($ReadinessReport.GapCount -eq 0) {
    Write-Host "✅ $Owner/$Repo is fully configured — no issues to create." -ForegroundColor Green
    return
}

Write-Host ""
Write-Host "📋 Found $($ReadinessReport.GapCount) gap(s) in $Owner/${Repo}:" -ForegroundColor Yellow
foreach ($gap in $ReadinessReport.Gaps) {
    Write-Host "   • $gap" -ForegroundColor DarkGray
}
Write-Host ""

# --- Resolve org issue type IDs ---

$ctx = Get-RepoContext -Owner $Owner -Repo $Repo
$repoId = $ctx.RepoId
$authenticatedUser = $ctx.ViewerLogin
$ownerType = $ctx.OwnerType

$epicTypeId = $null
$taskTypeId = $null

if ($ownerType -eq "Organization") {
    $epicTypeId = ($ctx.IssueTypes | Where-Object { $_.name -eq "Epic" }).id
    $taskTypeId  = ($ctx.IssueTypes | Where-Object { $_.name -eq "Task" }).id
}

# --- Helper: create a single issue via GraphQL ---

function New-TrackingIssue {
    param(
        [string]$Title,
        [string]$Body,
        [string]$TypeId,
        [string]$RepoId,
        [string]$Assignee
    )

    $escapedBody = $Body -replace '\\', '\\\\' -replace '"', '\"' -replace "`r`n", '\n' -replace "`n", '\n'

    $mutation = @"
mutation {
  createIssue(input: {
    repositoryId: "$RepoId"
    title: "$Title"
    body: "$escapedBody"
    $(if ($TypeId) { "issueTypeId: `"$TypeId`"" })
  }) {
    issue { id number url title }
  }
}
"@

    $issueResult = Invoke-GraphQL -Query $mutation
    $newIssue = $issueResult.data.createIssue.issue

    # Assign to copilot (Task) or authenticated user (Epic) via REST
    if ($Assignee -eq "@copilot") {
        gh api "repos/$Owner/$Repo/issues/$($newIssue.number)/assignees" `
            --method POST -f "assignees[]=Copilot" 2>&1 | Out-Null
    } elseif ($Assignee -and $Assignee -ne "") {
        gh api "repos/$Owner/$Repo/issues/$($newIssue.number)/assignees" `
            --method POST -f "assignees[]=$Assignee" 2>&1 | Out-Null
    }

    return $newIssue
}

# --- Helper: link child issue to parent ---

function Add-SubIssue {
    param([string]$ParentId, [string]$ChildId)

    $mutation = @"
mutation {
  addSubIssue(input: { issueId: "$ParentId", subIssueId: "$ChildId" }) {
    issue { id }
    subIssue { id }
  }
}
"@
    try {
        Invoke-GraphQL -Query $mutation -Headers @{"GraphQL-Features" = "sub_issues"} | Out-Null
    } catch {
        Write-Warning "Could not link sub-issue: $_"
    }
}

# --- Define gap → issue mapping ---

$gapIssues = @{
    "CopilotInstructions" = [PSCustomObject]@{
        Title = "Add .github/copilot-instructions.md"
        Body  = @"
## Task
Create \`.github/copilot-instructions.md\` for the \`$Owner/$Repo\` repository using the Anokye Labs template.

## Context
This file is read automatically by GitHub Copilot in VS Code agent mode and by the \`@copilot\` coding agent on every session. Without it, agents have no context about the repository conventions, tech stack, or working practices.

## Acceptance Criteria
- [ ] \`.github/copilot-instructions.md\` is created with ≥50 lines
- [ ] File includes: tech stack section, coding conventions, testing requirements, file organization
- [ ] File documents how this repository uses GitHub issues and the Anokye System
- [ ] Copilot can answer questions about repo conventions by referencing the file

## Resources
- Template: \`.github/skills/okyerema/templates/copilot-instructions.md\`
- Reference: [agentic-workflows.md](references/agentic-workflows.md#copilot-instructions-integration)

## Out of Scope
- Do not change existing code or workflows
"@
    }
    "AgenticWorkflows" = [PSCustomObject]@{
        Title = "Add agentic workflows to .github/aw/"
        Body  = @"
## Task
Create the \`.github/aw/\` directory and add compiled agentic workflow files (\`.lock.yml\`) for automated issue governance.

## Context
Agentic workflows (via \`gh-aw\`) automate issue triage, stale detection, PR health monitoring, and lifecycle governance. Without them, all governance requires manual Okyerema interaction.

## Recommended Starter Workflows
1. **issue-triage.md** — Auto-label and triage new issues
2. **stale-patrol.md** — Flag and close abandoned issues (daily schedule)
3. **pr-health.md** — Nudge reviewers on stalled PRs

## Acceptance Criteria
- [ ] \`.github/aw/\` directory exists
- [ ] At least one \`.lock.yml\` compiled workflow file is present
- [ ] Workflows are triggered by appropriate GitHub events
- [ ] Least-privilege permissions are applied

## Resources
- Reference: [agentic-workflows.md](references/agentic-workflows.md#layer-3-agentic-workflows-gh-aw)
- Install gh-aw: \`gh extension install github/gh-aw\`
- Compile: \`gh aw compile\`

## Out of Scope
- Do not modify existing GitHub Actions workflows
"@
    }
    "ProjectLinked" = [PSCustomObject]@{
        Title = "Create and link GitHub Project board"
        Body  = @"
## Task
Create a GitHub Projects V2 board and link it to the \`$Owner/$Repo\` repository.

## Context
Without a project board, there is no visibility into work status at a glance. The Anokye System uses GitHub Projects V2 for sprint/kanban tracking with \`Status\`, \`Priority\`, and \`Sprint\` fields.

## Acceptance Criteria
- [ ] A GitHub Projects V2 board is created under the \`$Owner\` organization
- [ ] The project is linked to \`$Owner/$Repo\`
- [ ] Project has at minimum a \`Status\` field with: Todo, In Progress, Done
- [ ] Existing open issues are added to the project

## Resources
- Reference: [projects.md](references/projects.md)
- Script: \`Add-IssuesToProject.ps1\`

## Out of Scope
- Do not migrate issues to a different repository
"@
    }
    "IssueTypes" = [PSCustomObject]@{
        Title = "Adopt organization issue types for $Repo"
        Body  = @"
## Task
Ensure all open issues in \`$Owner/$Repo\` use organization-level issue types (Epic, Feature, Task, Bug) instead of labels or title prefixes.

## Context
Using labels like \`epic\`, \`task\`, \`feature\` as type substitutes is an anti-pattern in the Anokye System. Issue types provide first-class filtering, reporting, and hierarchy support. Labels should be reserved for categorization (e.g., \`documentation\`, \`security\`).

## Acceptance Criteria
- [ ] All open issues are assigned an appropriate issue type (Epic/Feature/Task/Bug)
- [ ] Labels used as type substitutes are removed or converted
- [ ] New issues follow the type assignment policy from SKILL.md

## Resources
- Reference: [issue-types.md](references/issue-types.md)
- Script: \`New-IssueWithType.ps1\`

## Out of Scope
- Do not close or modify issue content — only update types and labels
"@
    }
    "CiWorkflows" = [PSCustomObject]@{
        Title = "Configure CI/CD workflows for $Repo"
        Body  = @"
## Task
Create \`.github/workflows/\` directory with foundational CI/CD workflow files for \`$Owner/$Repo\`.

## Context
Without CI/CD, there are no automated quality gates. The Anokye System relies on CI checks as required gates for pull request merges and to prevent agents from introducing regressions.

## Recommended Starter Workflows
1. **validate.yml** — Lint and test on push/PR
2. **require-linked-issue.yml** — Ensure PRs reference an issue

## Acceptance Criteria
- [ ] \`.github/workflows/\` directory exists with at least one \`.yml\` file
- [ ] CI runs on push and pull_request events
- [ ] Branch protection references CI job names as required checks

## Resources
- Reference: [agentic-workflows.md](references/agentic-workflows.md)
- Example: \`.github/workflows/validate-plugin.yml\` in anokye-labs/plugins

## Out of Scope
- Do not modify existing workflows
"@
    }
}

# --- Create or use parent Epic ---

$createdIssues = @()

$epicIssue = $null

if ($ParentIssueNumber -gt 0) {
    # Resolve existing parent issue node ID
    $parentQuery = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    issue(number: $ParentIssueNumber) {
      id number title
    }
  }
}
"@
    $rawParent = Invoke-GraphQL -Query $parentQuery
    $epicIssue = $rawParent.data.repository.issue
    Write-Host "🔗 Using existing issue #$($epicIssue.number) as parent Epic: $($epicIssue.title)" -ForegroundColor Cyan
} else {
    $epicTitle = "Repo Automation Onboarding: $Owner/$Repo"
    $epicBody  = @"
## Summary
This Epic tracks the missing automation infrastructure for \`$Owner/$Repo\`. Each sub-task addresses one readiness gap identified by \`Get-RepoReadiness.ps1\`.

## Readiness Score
Current: **$($ReadinessReport.ReadinessScore)/100**

## Gaps
$(($ReadinessReport.Gaps | ForEach-Object { "- [ ] $_" }) -join "`n")

## Resources
- Script: \`Get-RepoReadiness.ps1\`
- Script: \`Initialize-RepoAutomation.ps1\`
- Reference: [agentic-workflows.md](references/agentic-workflows.md)
"@

    if ($WhatIf) {
        Write-Host "[WhatIf] Would create Epic: '$epicTitle'" -ForegroundColor DarkYellow
    } else {
        Write-Host "📌 Creating parent Epic: $epicTitle" -ForegroundColor Cyan
        $epicIssue = New-TrackingIssue -Title $epicTitle -Body $epicBody -TypeId $epicTypeId -RepoId $repoId -Assignee $authenticatedUser
        if ($epicIssue) {
            $createdIssues += $epicIssue
            Write-Host "   ✅ Epic #$($epicIssue.number): $($epicIssue.title)" -ForegroundColor Green
        }
    }
}

# --- Create a Task for each gap ---

foreach ($gap in $ReadinessReport.Gaps) {
    $def = $gapIssues[$gap]
    if (-not $def) {
        Write-Warning "No issue template defined for gap: $gap"
        continue
    }

    if ($WhatIf) {
        Write-Host "[WhatIf] Would create Task: '$($def.Title)'" -ForegroundColor DarkYellow
        continue
    }

    Write-Host "🔧 Creating task for gap '$gap': $($def.Title)" -ForegroundColor White
    $taskIssue = New-TrackingIssue -Title $def.Title -Body $def.Body -TypeId $taskTypeId -RepoId $repoId -Assignee "@copilot"

    if ($taskIssue) {
        $createdIssues += $taskIssue
        Write-Host "   ✅ Task #$($taskIssue.number): $($taskIssue.title)" -ForegroundColor Green

        # Link to parent Epic
        if ($epicIssue) {
            Add-SubIssue -ParentId $epicIssue.id -ChildId $taskIssue.id
        }
    }
}

# --- Summary ---

Write-Host ""
if ($WhatIf) {
    Write-Host "✅ WhatIf complete — no issues were created." -ForegroundColor Cyan
} else {
    Write-Host "✅ Created $($createdIssues.Count) issue(s) for $Owner/${Repo}:" -ForegroundColor Green
    foreach ($issue in $createdIssues) {
        Write-Host "   #$($issue.number) $($issue.title)  →  $($issue.url)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "💡 Next step: re-run Get-RepoReadiness.ps1 after addressing gaps." -ForegroundColor Cyan
}
Write-Host ""

# Emit created issues list to pipeline
Write-Output $createdIssues
