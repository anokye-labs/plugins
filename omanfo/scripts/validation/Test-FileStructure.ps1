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

# Discover skills by scanning skills/ directory for SKILL.md files
$skillsDir = Join-Path $pluginDir "skills"
if (-not (Test-Path $skillsDir)) {
    Write-Host "ℹ skills/ directory not found at: $skillsDir" -ForegroundColor Cyan
    Write-Host "✓ Skipping file structure validation (skills may be at .github/skills/)" -ForegroundColor Green
    exit 0
}

$skillDirs = @(Get-ChildItem $skillsDir -Directory)
if ($skillDirs.Count -eq 0) {
    Write-Host "ℹ No skill directories found under: $skillsDir" -ForegroundColor Cyan
    Write-Host "✓ Skipping file structure validation (skills may be at .github/skills/)" -ForegroundColor Green
    exit 0
}

# Validate each skill
foreach ($dir in $skillDirs) {
    $skillName = $dir.Name
    $skillPath = $dir.FullName
    Write-Host "`nValidating skill: $skillName" -ForegroundColor Cyan
    
    # Check SKILL.md
    $skillMd = Join-Path $skillPath "SKILL.md"
    if (Test-Path $skillMd) {
        Write-ValidationSuccess "[$skillName] SKILL.md exists"
    } else {
        Write-ValidationError "[$skillName] SKILL.md not found at: $skillMd"
    }
    
    # Check references directory
    $referencesDir = Join-Path $skillPath "references"
    if (Test-Path $referencesDir) {
        $refFiles = @(Get-ChildItem -Path $referencesDir -Filter "*.md" -File)
        if ($refFiles.Count -gt 0) {
            Write-ValidationSuccess "[$skillName] references/ directory exists with $($refFiles.Count) markdown files"
        } else {
            Write-ValidationError "[$skillName] references/ directory exists but has no markdown files"
        }
    }
    
    # Check scripts directory
    $scriptsDir = Join-Path $skillPath "scripts"
    if (Test-Path $scriptsDir) {
        $scriptFiles = @(Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -File)
        if ($scriptFiles.Count -gt 0) {
            Write-ValidationSuccess "[$skillName] scripts/ directory exists with $($scriptFiles.Count) PowerShell scripts"
        } else {
            Write-ValidationError "[$skillName] scripts/ directory exists but has no PowerShell scripts"
        }
    }
}

Write-Host "`n" -NoNewline
if ($script:exitCode -eq 0) {
    Write-Host "✅ File structure validation passed" -ForegroundColor Green
} else {
    Write-Host "❌ File structure validation failed" -ForegroundColor Red
}

exit $script:exitCode
