#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that manifest.json matches actual files on disk.

.DESCRIPTION
    This script verifies:
    1. Every file listed in manifest.json exists on disk
    2. Every file on disk (references/*.md, scripts/*.ps1) is in the manifest
    3. File counts in manifest match actual counts

.PARAMETER PluginPath
    Path to the plugin directory (e.g., omanfo or okyeame). Defaults to omanfo.

.EXAMPLE
    ./Test-ManifestConsistency.ps1 -PluginPath omanfo
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$PluginPath = "omanfo"
)

$ErrorActionPreference = 'Stop'
$script:exitCode = 0

function Write-ValidationError {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
    $script:exitCode = 1
}

function Write-ValidationSuccess {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

# Resolve plugin path
$pluginDir = if ([System.IO.Path]::IsPathRooted($PluginPath)) {
    $PluginPath
} else {
    # Get repo root (3 levels up from scripts/validation/)
    $repoRoot = Join-Path $PSScriptRoot "../../.." | Resolve-Path -ErrorAction Stop
    Join-Path $repoRoot $PluginPath | Resolve-Path -ErrorAction Stop
}

Write-Host "`n🔍 Validating manifest consistency for: $pluginDir`n" -ForegroundColor Cyan

# Load manifest
$manifestPath = Join-Path $pluginDir "manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-ValidationError "manifest.json not found at: $manifestPath"
    exit 1
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$skillPath = Join-Path $pluginDir $manifest.skill.path

# Check if skill directory exists
if (-not (Test-Path $skillPath)) {
    Write-ValidationError "Skill directory not found: $skillPath"
    exit 1
}

# Count references
$referencesDir = Join-Path $skillPath "references"
$actualReferences = @()
if (Test-Path $referencesDir) {
    $actualReferences = @(Get-ChildItem -Path $referencesDir -Filter "*.md" -File)
}

$manifestReferences = $manifest.skill.references
if ($actualReferences.Count -ne $manifestReferences) {
    Write-ValidationError "Reference count mismatch: manifest=$manifestReferences, actual=$($actualReferences.Count)"
} else {
    Write-ValidationSuccess "Reference count matches: $($actualReferences.Count)"
}

# Count scripts
$scriptsDir = Join-Path $skillPath "scripts"
$actualScripts = @()
if (Test-Path $scriptsDir) {
    $actualScripts = @(Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -File)
}

$manifestScripts = $manifest.skill.scripts
if ($actualScripts.Count -ne $manifestScripts) {
    Write-ValidationError "Script count mismatch: manifest=$manifestScripts, actual=$($actualScripts.Count)"
} else {
    Write-ValidationSuccess "Script count matches: $($actualScripts.Count)"
}

# Verify SKILL.md exists
$skillMd = Join-Path $skillPath $manifest.skill.entryPoint
if (-not (Test-Path $skillMd)) {
    Write-ValidationError "SKILL.md not found at: $skillMd"
} else {
    Write-ValidationSuccess "SKILL.md exists"
}

# Count evaluations if specified
if ($manifest.evaluations) {
    $evalPath = Join-Path $pluginDir $manifest.evaluations.path
    $actualEvals = @()
    if (Test-Path $evalPath) {
        $actualEvals = @(Get-ChildItem -Path $evalPath -Filter "*.eval.md" -File)
    }
    
    $manifestEvalCount = $manifest.evaluations.count
    if ($actualEvals.Count -ne $manifestEvalCount) {
        Write-ValidationError "Evaluation count mismatch: manifest=$manifestEvalCount, actual=$($actualEvals.Count)"
    } else {
        Write-ValidationSuccess "Evaluation count matches: $($actualEvals.Count)"
    }
}

Write-Host "`n" -NoNewline
if ($script:exitCode -eq 0) {
    Write-Host "✅ Manifest consistency validation passed" -ForegroundColor Green
} else {
    Write-Host "❌ Manifest consistency validation failed" -ForegroundColor Red
}

exit $script:exitCode
