#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates required file structure for a plugin.

.DESCRIPTION
    This script verifies:
    1. SKILL.md exists in the skill directory
    2. references/ directory exists with at least one .md file
    3. scripts/ directory exists with at least one .ps1 file

.PARAMETER PluginPath
    Path to the plugin directory (e.g., omanfo or okyeame). Defaults to omanfo.

.EXAMPLE
    ./Test-FileStructure.ps1 -PluginPath omanfo
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

Write-Host "`n🔍 Validating file structure for: $pluginDir`n" -ForegroundColor Cyan

# Load manifest to get skill path
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
    
    # Check SKILL.md
    $skillMd = Join-Path $skillPath "SKILL.md"
    if (Test-Path $skillMd) {
        Write-ValidationSuccess "[$($skill.name)] SKILL.md exists"
    } else {
        Write-ValidationError "[$($skill.name)] SKILL.md not found at: $skillMd"
    }
    
    # Check references directory
    $referencesDir = Join-Path $skillPath "references"
    $expectedRefs = $skill.references
    if ($expectedRefs -gt 0) {
        if (Test-Path $referencesDir) {
            $refFiles = @(Get-ChildItem -Path $referencesDir -Filter "*.md" -File)
            if ($refFiles.Count -gt 0) {
                Write-ValidationSuccess "[$($skill.name)] references/ directory exists with $($refFiles.Count) markdown files"
            } else {
                Write-ValidationError "[$($skill.name)] references/ directory exists but has no markdown files"
            }
        } else {
            Write-ValidationError "[$($skill.name)] references/ directory not found at: $referencesDir"
        }
    } else {
        Write-ValidationSuccess "[$($skill.name)] No references expected (manifest count: 0)"
    }
    
    # Check scripts directory
    $scriptsDir = Join-Path $skillPath "scripts"
    $expectedScripts = $skill.scripts
    if ($expectedScripts -gt 0) {
        if (Test-Path $scriptsDir) {
            $scriptFiles = @(Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -File)
            if ($scriptFiles.Count -gt 0) {
                Write-ValidationSuccess "[$($skill.name)] scripts/ directory exists with $($scriptFiles.Count) PowerShell scripts"
            } else {
                Write-ValidationError "[$($skill.name)] scripts/ directory exists but has no PowerShell scripts"
            }
        } else {
            Write-ValidationError "[$($skill.name)] scripts/ directory not found at: $scriptsDir"
        }
    } else {
        Write-ValidationSuccess "[$($skill.name)] No scripts expected (manifest count: 0)"
    }
}

Write-Host "`n" -NoNewline
if ($script:exitCode -eq 0) {
    Write-Host "✅ File structure validation passed" -ForegroundColor Green
} else {
    Write-Host "❌ File structure validation failed" -ForegroundColor Red
}

exit $script:exitCode
