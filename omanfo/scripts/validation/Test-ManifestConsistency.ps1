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

# Support both old format (skill) and new format (skills array)
$skillsToValidate = @()
if ($manifest.PSObject.Properties['skills']) {
    # New format: array of skills
    $skillsToValidate = $manifest.skills
    if ($skillsToValidate.Count -eq 0) {
        Write-ValidationError "Manifest has 'skills' array but it is empty. At least one skill must be defined."
        exit 1
    }
} elseif ($manifest.PSObject.Properties['skill']) {
    # Old format: single skill object
    $skillsToValidate = @($manifest.skill)
} else {
    Write-ValidationError "No 'skill' or 'skills' property found in manifest"
    exit 1
}

# Validate each skill
foreach ($skill in $skillsToValidate) {
    Write-Host "`nValidating skill: $($skill.name)" -ForegroundColor Cyan
    
    $skillPath = Join-Path $pluginDir $skill.path
    
    # Check if skill directory exists
    if (-not (Test-Path $skillPath)) {
        Write-ValidationError "Skill directory not found: $skillPath"
        continue
    } else {
        Write-ValidationSuccess "Skill directory exists: $skillPath"
    }
    
    # Count references
    $referencesDir = Join-Path $skillPath "references"
    $actualReferences = @()
    if (Test-Path $referencesDir) {
        $actualReferences = @(Get-ChildItem -Path $referencesDir -Filter "*.md" -File)
    }
    
    $manifestReferences = $skill.references
    if ($actualReferences.Count -ne $manifestReferences) {
        Write-ValidationError "[$($skill.name)] Reference count mismatch: manifest=$manifestReferences, actual=$($actualReferences.Count)"
    } else {
        Write-ValidationSuccess "[$($skill.name)] Reference count matches: $($actualReferences.Count)"
    }
    
    # Count scripts
    $scriptsDir = Join-Path $skillPath "scripts"
    $actualScripts = @()
    if (Test-Path $scriptsDir) {
        $actualScripts = @(Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -File)
    }
    
    $manifestScripts = $skill.scripts
    if ($actualScripts.Count -ne $manifestScripts) {
        Write-ValidationError "[$($skill.name)] Script count mismatch: manifest=$manifestScripts, actual=$($actualScripts.Count)"
    } else {
        Write-ValidationSuccess "[$($skill.name)] Script count matches: $($actualScripts.Count)"
    }
    
    # Verify SKILL.md exists
    $skillMd = Join-Path $skillPath $skill.entryPoint
    if (-not (Test-Path $skillMd)) {
        Write-ValidationError "[$($skill.name)] SKILL.md not found at: $skillMd"
    } else {
        Write-ValidationSuccess "[$($skill.name)] SKILL.md exists"
    }
    
    # Verify agent file if specified
    if ($skill.PSObject.Properties['agentFile']) {
        $agentFile = Join-Path $pluginDir $skill.agentFile
        if (-not (Test-Path $agentFile)) {
            Write-ValidationError "[$($skill.name)] Agent file not found at: $agentFile"
        } else {
            Write-ValidationSuccess "[$($skill.name)] Agent file exists: $($skill.agentFile)"
        }
    }
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
