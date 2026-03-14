<#
.SYNOPSIS
    Installs Okyerema workflow templates and scripts into a target repository.

.DESCRIPTION
    Copies distributable GitHub Actions workflow templates from okyerema/workflows/
    into the target repository's .github/workflows/ directory. Also copies the
    copilot-instructions template if one doesn't already exist.

.PARAMETER TargetRepo
    Path to the target repository root.

.PARAMETER WorkflowsOnly
    If set, only copies workflow files (skips copilot-instructions).

.PARAMETER Force
    If set, overwrites existing workflow files.

.EXAMPLE
    .\Install-Okyerema.ps1 -TargetRepo C:\src\my-project

.EXAMPLE
    .\Install-Okyerema.ps1 -TargetRepo ../my-project -WorkflowsOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TargetRepo,

    [switch]$WorkflowsOnly,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $PSScriptRoot  # okyerema/ directory

# Resolve target path
$targetPath = Resolve-Path $TargetRepo -ErrorAction Stop
$targetWorkflows = Join-Path $targetPath ".github/workflows"

Write-Host "`nInstalling Okyerema to: $targetPath" -ForegroundColor Cyan

# Create target directories
if (-not (Test-Path $targetWorkflows)) {
    New-Item -Path $targetWorkflows -ItemType Directory -Force | Out-Null
    Write-Host "  Created .github/workflows/" -ForegroundColor Gray
}

# Copy workflow templates
$sourceWorkflows = Join-Path $scriptRoot "workflows"
$workflowFiles = Get-ChildItem -Path $sourceWorkflows -Filter "*.yml" -ErrorAction SilentlyContinue

if ($workflowFiles.Count -eq 0) {
    Write-Warning "No workflow templates found in $sourceWorkflows"
} else {
    $copied = 0
    foreach ($file in $workflowFiles) {
        $targetFile = Join-Path $targetWorkflows $file.Name
        if ((Test-Path $targetFile) -and -not $Force) {
            Write-Host "  Skipping (exists): $($file.Name)" -ForegroundColor Yellow
        } else {
            Copy-Item -Path $file.FullName -Destination $targetFile -Force
            $copied++
            Write-Host "  Copied: $($file.Name)" -ForegroundColor Green
        }
    }
    Write-Host "`n  $copied of $($workflowFiles.Count) workflow(s) installed" -ForegroundColor Cyan
}

# Copy copilot-instructions if not exists
if (-not $WorkflowsOnly) {
    $targetInstructions = Join-Path $targetPath ".github/copilot-instructions.md"
    if (-not (Test-Path $targetInstructions)) {
        $templatePath = Join-Path $scriptRoot "skills/rhythm/references/agentic-workflows.md"
        if (Test-Path $templatePath) {
            $githubDir = Join-Path $targetPath ".github"
            if (-not (Test-Path $githubDir)) {
                New-Item -Path $githubDir -ItemType Directory -Force | Out-Null
            }
            # Create a minimal copilot-instructions pointing to the skill
            $instructions = @"
# Repository Agent Instructions

This repository uses the Anokye System for project management.

## Conventions

- Use GitHub organization issue types (Epic, Feature, Task, Bug)
- Use GraphQL API for all write operations
- Use sub-issues API for parent-child relationships
- Hierarchy: Epic → Feature → Task (3 levels) or Epic → Task (2 levels)
- Tasks and Bugs auto-assign to @copilot; Epics and Features to humans

## References

See the Okyerema plugin for detailed workflow and automation guides.
"@
            Set-Content -Path $targetInstructions -Value $instructions
            Write-Host "  Created .github/copilot-instructions.md" -ForegroundColor Green
        }
    } else {
        Write-Host "  .github/copilot-instructions.md already exists, skipping" -ForegroundColor Yellow
    }
}

Write-Host "`nInstallation complete." -ForegroundColor Green
Write-Host "Configure repository variables (Settings → Secrets and variables → Variables):" -ForegroundColor Cyan
Write-Host "  COPILOT_DISPATCH_PAT — PAT with issue:write for Copilot assignment" -ForegroundColor Gray
Write-Host "  TRUSTED_ACTORS — JSON array of trusted PR authors for auto-approve" -ForegroundColor Gray
