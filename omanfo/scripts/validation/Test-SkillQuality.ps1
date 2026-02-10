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

# Load manifest to get skill path
$manifestPath = Join-Path $pluginDir "manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-ValidationError "manifest.json not found at: $manifestPath"
    exit 1
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$skillPath = Join-Path $pluginDir $manifest.skill.path
$skillMd = Join-Path $skillPath "SKILL.md"

if (-not (Test-Path $skillMd)) {
    Write-ValidationError "SKILL.md not found at: $skillMd"
    exit 1
}

# Check line count
$lines = Get-Content $skillMd
$lineCount = $lines.Count

if ($lineCount -le 500) {
    Write-ValidationSuccess "SKILL.md has $lineCount lines (under 500 line limit)"
} else {
    Write-ValidationError "SKILL.md has $lineCount lines (exceeds 500 line limit)"
}

# Check for YAML frontmatter
$content = Get-Content $skillMd -Raw

# Check if file starts with ---
if (-not $content.TrimStart().StartsWith('---')) {
    Write-ValidationError "SKILL.md does not start with YAML frontmatter (---)"
    exit $script:exitCode
}

# Extract frontmatter
$frontmatterMatch = [regex]::Match($content, '(?s)^---\s*\n(.*?)\n---')
if (-not $frontmatterMatch.Success) {
    Write-ValidationError "SKILL.md has invalid YAML frontmatter structure"
    exit $script:exitCode
}

Write-ValidationSuccess "SKILL.md has valid YAML frontmatter structure"

$frontmatter = $frontmatterMatch.Groups[1].Value

# Check for required fields
if ($frontmatter -match '^\s*name:\s*\S' -or $frontmatter -match '\n\s*name:\s*\S') {
    Write-ValidationSuccess "YAML frontmatter contains 'name' field"
} else {
    Write-ValidationError "YAML frontmatter missing 'name' field"
}

if ($frontmatter -match '^\s*description:\s*\S' -or $frontmatter -match '\n\s*description:\s*\S') {
    Write-ValidationSuccess "YAML frontmatter contains 'description' field"
} else {
    Write-ValidationError "YAML frontmatter missing 'description' field"
}

Write-Host "`n" -NoNewline
if ($script:exitCode -eq 0) {
    Write-Host "✅ SKILL.md quality validation passed" -ForegroundColor Green
} else {
    Write-Host "❌ SKILL.md quality validation failed" -ForegroundColor Red
}

exit $script:exitCode
