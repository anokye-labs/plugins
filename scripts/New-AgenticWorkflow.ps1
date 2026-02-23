#Requires -Version 5.1
<#
.SYNOPSIS
    Install an agentic workflow template into a target repository.

.DESCRIPTION
    Copies a workflow template `.md` file from the `workflow-templates/agentic/`
    directory into the target repository's `.github/workflows/` directory, then
    runs `gh aw compile` to generate the corresponding `.lock.yml` file, and
    commits both files.

    Available templates: issue-triage, stale-patrol, pr-health, issue-lifecycle, pr-triage

.PARAMETER TemplateName
    Name of the template to install (e.g., issue-triage, stale-patrol, pr-health,
    issue-lifecycle, pr-triage).

.PARAMETER TargetRepoPath
    Absolute or relative path to the root of the target repository.

.PARAMETER DryRun
    Preview what would happen without copying files, compiling, or committing.

.EXAMPLE
    .\New-AgenticWorkflow.ps1 -TemplateName issue-triage -TargetRepoPath ../my-repo

.EXAMPLE
    .\New-AgenticWorkflow.ps1 -TemplateName stale-patrol -TargetRepoPath C:\repos\my-repo -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TemplateName,

    [Parameter(Mandatory)]
    [string]$TargetRepoPath,

    [Parameter()]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step {
    param([string]$Message)
    Write-Host "▶ $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Preview {
    param([string]$Message)
    Write-Host "  [DryRun] $Message" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$repoRoot      = Split-Path $scriptDir -Parent
$templatesDir  = Join-Path $repoRoot "workflow-templates" "agentic"
$resolvedTargetRaw = Resolve-Path $TargetRepoPath -ErrorAction SilentlyContinue
$resolvedTarget = if ($resolvedTargetRaw) { $resolvedTargetRaw.Path } else { $TargetRepoPath }
$workflowsDir  = Join-Path $resolvedTarget ".github" "workflows"

# ---------------------------------------------------------------------------
# Validate template name
# ---------------------------------------------------------------------------

$availableTemplates = @('issue-triage', 'stale-patrol', 'pr-health', 'issue-lifecycle', 'pr-triage')

if ($TemplateName -notin $availableTemplates) {
    $list = $availableTemplates -join ', '
    Write-Error "Unknown template '$TemplateName'. Available templates: $list"
    return
}

$templateFile = Join-Path $templatesDir "$TemplateName.md"
if (-not (Test-Path $templateFile)) {
    Write-Error "Template file not found: $templateFile"
    return
}

# ---------------------------------------------------------------------------
# Validate target repository
# ---------------------------------------------------------------------------

if (-not (Test-Path $resolvedTarget)) {
    Write-Error "Target repository path not found: $resolvedTarget"
    return
}

if (-not (Test-Path (Join-Path $resolvedTarget ".git"))) {
    Write-Error "Target path is not a git repository: $resolvedTarget"
    return
}

# ---------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------

$destFile    = Join-Path $workflowsDir "$TemplateName.md"
$lockFile    = Join-Path $workflowsDir "$TemplateName.lock.yml"
$relMdPath   = ".github/workflows/$TemplateName.md"
$relLockPath = ".github/workflows/$TemplateName.lock.yml"

Write-Step "Installing agentic workflow: $TemplateName"
Write-Host "  Source    : $templateFile"
Write-Host "  Target dir: $workflowsDir"
Write-Host "  DryRun    : $($DryRun.IsPresent)"
Write-Host ""

# ---------------------------------------------------------------------------
# Copy template
# ---------------------------------------------------------------------------

Write-Step "Copying template to $relMdPath"

if ($DryRun) {
    Write-Preview "Would copy '$templateFile' -> '$destFile'"
} else {
    if (-not (Test-Path $workflowsDir)) {
        New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null
    }
    Copy-Item -Path $templateFile -Destination $destFile -Force
    Write-Ok "Copied $TemplateName.md"
}

# ---------------------------------------------------------------------------
# Compile
# ---------------------------------------------------------------------------

Write-Step "Running 'gh aw compile' in target repository"

if ($DryRun) {
    Write-Preview "Would run: gh aw compile (in $resolvedTarget)"
    Write-Preview "Would generate: $relLockPath"
} else {
    Push-Location $resolvedTarget
    try {
        $compileOutput = & gh aw compile 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "gh aw compile failed (exit $LASTEXITCODE):`n$compileOutput"
            return
        }
        Write-Ok "Compiled $TemplateName.lock.yml"
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# Commit
# ---------------------------------------------------------------------------

Write-Step "Committing changes"

if ($DryRun) {
    Write-Preview "Would run: git add $relMdPath $relLockPath"
    Write-Preview "Would run: git commit -m `"Add $TemplateName agentic workflow`""
} else {
    Push-Location $resolvedTarget
    try {
        & git add $relMdPath $relLockPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "git add failed"
            return
        }

        & git commit -m "Add $TemplateName agentic workflow" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "git commit failed"
            return
        }
        Write-Ok "Committed $relMdPath and $relLockPath"
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

Write-Host ""
if ($DryRun) {
    Write-Host "✓ Dry run complete — no changes made." -ForegroundColor Yellow
} else {
    Write-Host "✅ $TemplateName installed successfully." -ForegroundColor Green
}

return [PSCustomObject]@{
    TemplateName = $TemplateName
    TargetPath   = $destFile
    LockPath     = $lockFile
    Installed    = (-not $DryRun.IsPresent)
    Compiled     = (-not $DryRun.IsPresent)
    Committed    = (-not $DryRun.IsPresent)
    DryRun       = $DryRun.IsPresent
}
