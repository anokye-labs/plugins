<#
.SYNOPSIS
    Verifies that the Okyerema plugin is correctly installed in a target repository.

.DESCRIPTION
    Checks that all expected files exist, validates JSON manifests, and verifies
    script syntax. Returns a structured report of what's present and what's missing.

.PARAMETER TargetRepo
    Path to the target repository root. If not specified, verifies the plugin source.

.EXAMPLE
    .\Verify-Installation.ps1
    .\Verify-Installation.ps1 -TargetRepo C:\src\my-project
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$TargetRepo
)

$ErrorActionPreference = "Stop"

if ($TargetRepo) {
    $basePath = Resolve-Path $TargetRepo -ErrorAction Stop
    $mode = "target"
} else {
    $basePath = Split-Path -Parent $PSScriptRoot  # okyerema/ directory
    $mode = "source"
}

Write-Host "`nVerifying Okyerema installation ($mode mode)" -ForegroundColor Cyan
Write-Host "Path: $basePath`n" -ForegroundColor Gray

$errors = 0
$warnings = 0
$checks = 0

function Test-FileExists {
    param([string]$Path, [string]$Description, [switch]$Required)
    $script:checks++
    $fullPath = Join-Path $basePath $Path
    if (Test-Path $fullPath) {
        Write-Host "  [PASS] $Description" -ForegroundColor Green
        return $true
    } else {
        if ($Required) {
            Write-Host "  [FAIL] $Description — missing: $Path" -ForegroundColor Red
            $script:errors++
        } else {
            Write-Host "  [WARN] $Description — missing: $Path" -ForegroundColor Yellow
            $script:warnings++
        }
        return $false
    }
}

# --- Source mode: verify plugin structure ---
if ($mode -eq "source") {
    Write-Host "Plugin Structure" -ForegroundColor Cyan
    Test-FileExists ".github/plugin/plugin.json" "Plugin manifest" -Required
    Test-FileExists "okyerema.agent.md" "Agent persona" -Required
    Test-FileExists "AGENTS.md" "Claude Code entry point" -Required
    Test-FileExists "README.md" "Plugin README" -Required

    Write-Host "`nSkills" -ForegroundColor Cyan
    Test-FileExists "skills/rhythm/SKILL.md" "Rhythm skill" -Required
    Test-FileExists "skills/sankofa/SKILL.md" "Sankofa skill" -Required

    Write-Host "`nRhythm Scripts" -ForegroundColor Cyan
    foreach ($script in @("Get-ReadyIssues", "Get-BlockedIssues", "Get-DagStatus", "Get-DagCompletionReport", "Get-StalledWork", "Invoke-DagHealthCheck", "Invoke-PRCompletion")) {
        Test-FileExists "scripts/rhythm/$script.ps1" $script -Required
    }

    Write-Host "`nDispatch Scripts" -ForegroundColor Cyan
    foreach ($script in @("Get-IssueTypeIds", "New-IssueWithType", "New-IssueBatch", "New-IssueHierarchy", "Update-IssueHierarchy", "Set-IssueDependency", "Test-Hierarchy", "Add-IssuesToProject", "Invoke-PlanMaterialization", "Sync-PlanToIssues")) {
        Test-FileExists "scripts/dispatch/$script.ps1" $script -Required
    }

    Write-Host "`nVerify Scripts" -ForegroundColor Cyan
    foreach ($script in @("Get-PRStatus", "Get-PRHealth", "Get-PRTimeline", "Get-ThreadSeverity", "Get-UnresolvedThreads", "Reply-ReviewThread", "Resolve-ReviewThreads", "Submit-PRReview", "Find-IssueByPR")) {
        Test-FileExists "scripts/verify/$script.ps1" $script -Required
    }

    Write-Host "`nHealth Scripts" -ForegroundColor Cyan
    foreach ($script in @("Get-HierarchyHealth", "Get-OrphanedIssues", "Get-Sitrep", "Get-RepoReadiness", "Initialize-RepoAutomation")) {
        Test-FileExists "scripts/health/$script.ps1" $script -Required
    }

    Write-Host "`nReferences" -ForegroundColor Cyan
    foreach ($ref in @("issue-types", "relationships", "projects", "pr-reviews", "agentic-workflows", "labels", "errors", "status-commands", "plan-materialization")) {
        Test-FileExists "skills/rhythm/references/$ref.md" $ref -Required
    }

    # Validate JSON manifest
    Write-Host "`nManifest Validation" -ForegroundColor Cyan
    $checks++
    try {
        $manifestPath = Join-Path $basePath ".github/plugin/plugin.json"
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-Host "  [PASS] plugin.json is valid JSON" -ForegroundColor Green

        # Check that item paths resolve
        foreach ($item in $manifest.items) {
            $checks++
            $itemPath = Join-Path $basePath $item.path
            if (Test-Path $itemPath) {
                Write-Host "  [PASS] Item path resolves: $($item.path)" -ForegroundColor Green
            } else {
                Write-Host "  [FAIL] Item path missing: $($item.path)" -ForegroundColor Red
                $errors++
            }
        }
    } catch {
        Write-Host "  [FAIL] plugin.json is invalid: $_" -ForegroundColor Red
        $errors++
    }

    # Validate PowerShell syntax
    Write-Host "`nPowerShell Syntax" -ForegroundColor Cyan
    $psFiles = Get-ChildItem -Path $basePath -Recurse -Filter "*.ps1"
    foreach ($file in $psFiles) {
        $checks++
        try {
            $null = [System.Management.Automation.ScriptBlock]::Create(
                (Get-Content $file.FullName -Raw)
            )
            Write-Host "  [PASS] $($file.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] $($file.Name) — syntax error: $_" -ForegroundColor Red
            $errors++
        }
    }
}

# --- Target mode: verify deployment ---
if ($mode -eq "target") {
    Write-Host "Workflow Templates" -ForegroundColor Cyan
    foreach ($wf in @("issue-dispatch", "copilot-checks", "auto-enqueue", "auto-approve", "post-merge", "sankofa-patrol", "auto-assign-unblocked")) {
        Test-FileExists ".github/workflows/$wf.yml" $wf
    }

    Write-Host "`nAgent Configuration" -ForegroundColor Cyan
    Test-FileExists ".github/copilot-instructions.md" "Copilot instructions"
    Test-FileExists "AGENTS.md" "Claude Code AGENTS.md"
    Test-FileExists ".claude/commands/sitrep.md" "Claude /sitrep command"
    Test-FileExists ".claude/commands/prcheck.md" "Claude /prcheck command"
    Test-FileExists ".claude/commands/health.md" "Claude /health command"
}

# --- Summary ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Checks: $checks" -ForegroundColor White
Write-Host "  Passed: $($checks - $errors - $warnings)" -ForegroundColor Green
Write-Host "  Warnings: $warnings" -ForegroundColor Yellow
Write-Host "  Errors: $errors" -ForegroundColor $(if ($errors -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

if ($errors -gt 0) {
    Write-Host "VERIFICATION FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "VERIFICATION PASSED" -ForegroundColor Green
    exit 0
}
