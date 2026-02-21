#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates SKILL.md quality requirements.

.DESCRIPTION
    This script verifies:
    1. SKILL.md is under 500 lines
    2. SKILL.md has valid YAML frontmatter (enclosed in ---)
    3. YAML frontmatter contains 'name' and 'description' fields

.PARAMETER PluginPath
    Path to the plugin directory (e.g., omanfo or okyeame). Defaults to omanfo.

.EXAMPLE
    ./Test-SkillQuality.ps1 -PluginPath omanfo
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

Write-Host "`n🔍 Validating SKILL.md quality for: $pluginDir`n" -ForegroundColor Cyan

# Discover skills by scanning skills/ directory
$skillsDir = Join-Path $pluginDir "skills"
if (-not (Test-Path $skillsDir)) {
    Write-Host "ℹ skills/ directory not found at: $skillsDir" -ForegroundColor Cyan
    Write-Host "✓ Skipping SKILL.md quality validation (skills may be at .github/skills/)" -ForegroundColor Green
    exit 0
}

$skillDirs = @(Get-ChildItem $skillsDir -Directory)

# Validate each skill
foreach ($dir in $skillDirs) {
    $skillName = $dir.Name
    $skillPath = $dir.FullName
    Write-Host "`nValidating skill: $skillName" -ForegroundColor Cyan
    
    $skillMd = Join-Path $skillPath "SKILL.md"
    
    if (-not (Test-Path $skillMd)) {
        Write-ValidationError "[$skillName] SKILL.md not found at: $skillMd"
        continue
    }
    
    # Check line count
    $lines = Get-Content $skillMd
    $lineCount = $lines.Count
    
    if ($lineCount -le 500) {
        Write-ValidationSuccess "[$skillName] SKILL.md has $lineCount lines (under 500 line limit)"
    } else {
        Write-ValidationError "[$skillName] SKILL.md has $lineCount lines (exceeds 500 line limit)"
    }
    
    # Check for YAML frontmatter
    $content = Get-Content $skillMd -Raw
    
    # Check if file starts with ---
    if (-not $content.StartsWith('---')) {
        Write-ValidationError "[$skillName] SKILL.md does not start with YAML frontmatter (---)"
        continue
    }
    
    # Extract frontmatter
    $frontmatterMatch = [regex]::Match($content, '(?s)^---\s*\n(.*?)\n---')
    if (-not $frontmatterMatch.Success) {
        Write-ValidationError "[$skillName] SKILL.md has invalid YAML frontmatter structure"
        continue
    }
    
    Write-ValidationSuccess "[$skillName] SKILL.md has valid YAML frontmatter structure"
    
    $frontmatter = $frontmatterMatch.Groups[1].Value
    
    # Check for required fields
    if ($frontmatter -match '^\s*name:\s*\S' -or $frontmatter -match '\n\s*name:\s*\S') {
        Write-ValidationSuccess "[$skillName] YAML frontmatter contains 'name' field"
    } else {
        Write-ValidationError "[$skillName] YAML frontmatter missing 'name' field"
    }
    
    if ($frontmatter -match '^\s*description:\s*\S' -or $frontmatter -match '\n\s*description:\s*\S') {
        Write-ValidationSuccess "[$skillName] YAML frontmatter contains 'description' field"
    } else {
        Write-ValidationError "[$skillName] YAML frontmatter missing 'description' field"
    }
}

Write-Host "`n" -NoNewline
if ($script:exitCode -eq 0) {
    Write-Host "✅ SKILL.md quality validation passed" -ForegroundColor Green
} else {
    Write-Host "❌ SKILL.md quality validation failed" -ForegroundColor Red
}

exit $script:exitCode
