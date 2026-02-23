#Requires -Version 5.1
<#
.SYNOPSIS
    Audit a repository for Anokye System automation infrastructure readiness.

.DESCRIPTION
    Checks whether a repository has the required automation infrastructure:
    - .github/copilot-instructions.md exists and is non-trivial (>50 lines)
    - .github/aw/ directory with compiled agentic workflow files
    - Active GitHub Project linked to the repository
    - Issue types in use (vs labels-as-types anti-pattern)
    - CI/CD workflows configured under .github/workflows/

    Returns a structured readiness report with a score and gap list suitable
    for the /context and /readiness commands.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER Brief
    If set, returns compact single-line summary.

.EXAMPLE
    .\Get-RepoReadiness.ps1 -Owner anokye-labs -Repo plugins

.EXAMPLE
    .\Get-RepoReadiness.ps1 -Owner anokye-labs -Repo akwaaba -Brief
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [switch]$Brief
)

$ErrorActionPreference = "Stop"

# --- Query repository structure and project linkage ---

$query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    id
    name
    owner {
      __typename
      ... on Organization {
        login
        issueTypes(first: 25) {
          nodes { id name }
        }
      }
      ... on User {
        login
      }
    }
    copilotInstructions: object(expression: "HEAD:.github/copilot-instructions.md") {
      ... on Blob {
        text
        byteSize
      }
    }
    agenticWorkflowsDir: object(expression: "HEAD:.github/aw") {
      ... on Tree {
        entries { name type }
      }
    }
    workflowsDir: object(expression: "HEAD:.github/workflows") {
      ... on Tree {
        entries { name type }
      }
    }
    openIssues: issues(states: OPEN, first: 50) {
      totalCount
      nodes {
        issueType { name }
        labels(first: 10) { nodes { name } }
      }
    }
    projectsV2(first: 10) {
      totalCount
      nodes {
        id
        title
        closed
        public
      }
    }
  }
}
"@

$rawResult = gh api graphql -f query="$query" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "GraphQL query failed: $rawResult"
    return
}
$result = $rawResult | ConvertFrom-Json

if ($result.errors) {
    Write-Error "GraphQL errors: $($result.errors | ConvertTo-Json -Compress)"
    return
}

$repoData = $result.data.repository

# --- Check 1: copilot-instructions.md ---

$copilotInstructionsOk = $false
$copilotInstructionsNote = "missing"

if ($repoData.copilotInstructions) {
    $text = $repoData.copilotInstructions.text
    $lineCount = ($text -split "`n").Count
    if ($lineCount -ge 50) {
        $copilotInstructionsOk = $true
        $copilotInstructionsNote = "present ($lineCount lines)"
    } else {
        $copilotInstructionsNote = "too short ($lineCount lines, need ≥50)"
    }
} else {
    $copilotInstructionsNote = "missing (.github/copilot-instructions.md not found)"
}

# --- Check 2: Agentic workflows (.github/aw/) ---

$agenticWorkflowsOk = $false
$agenticWorkflowsNote = "missing"
$agenticWorkflowCount = 0

if ($repoData.agenticWorkflowsDir -and $repoData.agenticWorkflowsDir.entries) {
    $lockFiles = $repoData.agenticWorkflowsDir.entries | Where-Object { $_.name -match '\.lock\.yml$' }
    $agenticWorkflowCount = ($lockFiles | Measure-Object).Count
    if ($agenticWorkflowCount -gt 0) {
        $agenticWorkflowsOk = $true
        $agenticWorkflowsNote = "present ($agenticWorkflowCount compiled workflow(s) in .github/aw/)"
    } else {
        $agenticWorkflowsNote = ".github/aw/ exists but no compiled .lock.yml workflows found"
    }
} else {
    $agenticWorkflowsNote = "missing (.github/aw/ directory not found)"
}

# --- Check 3: GitHub Project linked ---

$projectLinkedOk = $false
$projectLinkedNote = "none"
$activeProjects = @()

if ($repoData.projectsV2 -and $repoData.projectsV2.totalCount -gt 0) {
    $activeProjects = @($repoData.projectsV2.nodes | Where-Object { -not $_.closed })
    if ($activeProjects.Count -gt 0) {
        $projectLinkedOk = $true
        $projectLinkedNote = "$($activeProjects.Count) active project(s): $($activeProjects.title -join ', ')"
    } else {
        $projectLinkedNote = "no active projects (all closed)"
    }
} else {
    $projectLinkedNote = "no GitHub Projects linked to this repository"
}

# --- Check 4: Issue types in use ---

$issueTypesOk = $false
$issueTypesNote = "not in use"

$ownerType = $repoData.owner.__typename
if ($ownerType -eq "Organization" -and $repoData.owner.issueTypes -and $repoData.owner.issueTypes.nodes.Count -gt 0) {
    $availableTypes = $repoData.owner.issueTypes.nodes.name

    # Check for labels-as-types anti-pattern
    $allLabels = @()
    foreach ($issue in $repoData.openIssues.nodes) {
        $allLabels += $issue.labels.nodes.name
    }
    $typelikeLabels = $allLabels | Where-Object { $_ -match '^(epic|feature|task|bug|story|chore)$' }
    $labelsAsTypes = ($typelikeLabels | Select-Object -Unique).Count -gt 0

    # Check whether issues have type set
    $typedIssues = @($repoData.openIssues.nodes | Where-Object { $_.issueType -ne $null })
    $totalIssues = $repoData.openIssues.totalCount

    if ($totalIssues -eq 0) {
        $issueTypesOk = $true
        $issueTypesNote = "no open issues yet; org has types: $($availableTypes -join ', ')"
    } elseif ($typedIssues.Count -gt 0) {
        $issueTypesOk = $true
        $pct = [math]::Round($typedIssues.Count / [math]::Min($totalIssues, 50) * 100)
        $issueTypesNote = "in use ($($typedIssues.Count)/$([math]::Min($totalIssues, 50)) sampled issues typed, ~${pct}%)"
        if ($labelsAsTypes) {
            $issueTypesNote += " ⚠️ labels-as-types anti-pattern detected: $($typelikeLabels | Select-Object -Unique | Sort-Object)"
        }
    } else {
        $issueTypesNote = "org has types ($($availableTypes -join ', ')) but none applied to open issues"
        if ($labelsAsTypes) {
            $issueTypesNote += "; labels-as-types anti-pattern detected"
        }
    }
} elseif ($ownerType -ne "Organization") {
    $issueTypesNote = "issue types require an organization-owned repository (this is user-owned)"
} else {
    $issueTypesNote = "no issue types configured in the organization"
}

# --- Check 5: CI/CD workflows ---

$ciWorkflowsOk = $false
$ciWorkflowsNote = "none"
$ciWorkflowCount = 0

if ($repoData.workflowsDir -and $repoData.workflowsDir.entries) {
    $ymlFiles = $repoData.workflowsDir.entries | Where-Object { $_.name -match '\.(yml|yaml)$' -and $_.type -eq "blob" }
    $ciWorkflowCount = ($ymlFiles | Measure-Object).Count
    if ($ciWorkflowCount -gt 0) {
        $ciWorkflowsOk = $true
        $ciWorkflowsNote = "present ($ciWorkflowCount workflow file(s) in .github/workflows/)"
    } else {
        $ciWorkflowsNote = ".github/workflows/ exists but no .yml workflow files found"
    }
} else {
    $ciWorkflowsNote = "missing (.github/workflows/ directory not found)"
}

# --- Compute readiness score (0-100) ---

$checks = @(
    [PSCustomObject]@{ Name = "CopilotInstructions"; Ok = $copilotInstructionsOk; Note = $copilotInstructionsNote; Weight = 25 }
    [PSCustomObject]@{ Name = "AgenticWorkflows";    Ok = $agenticWorkflowsOk;    Note = $agenticWorkflowsNote;    Weight = 20 }
    [PSCustomObject]@{ Name = "ProjectLinked";       Ok = $projectLinkedOk;       Note = $projectLinkedNote;       Weight = 20 }
    [PSCustomObject]@{ Name = "IssueTypes";          Ok = $issueTypesOk;          Note = $issueTypesNote;          Weight = 20 }
    [PSCustomObject]@{ Name = "CiWorkflows";         Ok = $ciWorkflowsOk;         Note = $ciWorkflowsNote;         Weight = 15 }
)

$score = ($checks | Where-Object { $_.Ok } | ForEach-Object { $_.Weight } | Measure-Object -Sum).Sum
$score = if ($null -eq $score) { 0 } else { $score }

$gaps = @($checks | Where-Object { -not $_.Ok } | Select-Object -ExpandProperty Name)

# --- Build result ---

$readinessReport = [PSCustomObject]@{
    Owner                   = $Owner
    Repo                    = $Repo
    ReadinessScore          = $score
    Gaps                    = $gaps
    GapCount                = $gaps.Count
    CopilotInstructionsOk   = $copilotInstructionsOk
    CopilotInstructionsNote = $copilotInstructionsNote
    AgenticWorkflowsOk      = $agenticWorkflowsOk
    AgenticWorkflowsNote    = $agenticWorkflowsNote
    AgenticWorkflowCount    = $agenticWorkflowCount
    ProjectLinkedOk         = $projectLinkedOk
    ProjectLinkedNote       = $projectLinkedNote
    ActiveProjects          = @($activeProjects)
    IssueTypesOk            = $issueTypesOk
    IssueTypesNote          = $issueTypesNote
    CiWorkflowsOk           = $ciWorkflowsOk
    CiWorkflowsNote         = $ciWorkflowsNote
    CiWorkflowCount         = $ciWorkflowCount
}

# --- Display ---

if ($Brief) {
    $icon = if ($score -ge 80) { "✅" } elseif ($score -ge 50) { "⚠️" } else { "🔴" }
    Write-Host "$icon ${Owner}/${Repo} readiness: ${score}/100 | $($gaps.Count) gap(s): $($gaps -join ', ')" -ForegroundColor Cyan
} else {
    $scoreColor = if ($score -ge 80) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "Red" }

    Write-Host ""
    Write-Host "🚀 Repo Readiness: $Owner/$Repo" -ForegroundColor Cyan
    Write-Host ""

    $icon = if ($copilotInstructionsOk) { "✅" } else { "❌" }
    Write-Host "$icon copilot-instructions.md: $copilotInstructionsNote" -ForegroundColor $(if ($copilotInstructionsOk) { "Green" } else { "Red" })

    $icon = if ($agenticWorkflowsOk) { "✅" } else { "❌" }
    Write-Host "$icon Agentic workflows: $agenticWorkflowsNote" -ForegroundColor $(if ($agenticWorkflowsOk) { "Green" } else { "Red" })

    $icon = if ($projectLinkedOk) { "✅" } else { "❌" }
    Write-Host "$icon GitHub Project: $projectLinkedNote" -ForegroundColor $(if ($projectLinkedOk) { "Green" } else { "Yellow" })

    $icon = if ($issueTypesOk) { "✅" } else { "❌" }
    Write-Host "$icon Issue types: $issueTypesNote" -ForegroundColor $(if ($issueTypesOk) { "Green" } else { "Yellow" })

    $icon = if ($ciWorkflowsOk) { "✅" } else { "❌" }
    Write-Host "$icon CI/CD workflows: $ciWorkflowsNote" -ForegroundColor $(if ($ciWorkflowsOk) { "Green" } else { "Red" })

    Write-Host ""
    Write-Host "💯 Readiness score: $score/100" -ForegroundColor $scoreColor

    if ($gaps.Count -gt 0) {
        Write-Host ""
        Write-Host "🔧 Gaps to address ($($gaps.Count)):" -ForegroundColor Yellow
        foreach ($gap in $gaps) {
            Write-Host "   • $gap" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "💡 Run Initialize-RepoAutomation.ps1 to create issues for each gap." -ForegroundColor Cyan
    } else {
        Write-Host "✅ Repository is fully configured for Anokye System automation." -ForegroundColor Green
    }
    Write-Host ""
}

# Emit structured object to pipeline
Write-Output $readinessReport
