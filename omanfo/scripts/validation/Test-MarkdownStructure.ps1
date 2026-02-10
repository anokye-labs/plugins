#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates markdown structure of evaluation files.

.DESCRIPTION
    This script verifies that evaluation files have required sections:
    1. Priority indicator (e.g., 🔴 Critical)
    2. Time estimate
    3. ## Objective section
    4. ## Test Steps section

.PARAMETER PluginPath
    Path to the plugin directory (e.g., omanfo or okyeame). Defaults to omanfo.

.EXAMPLE
    ./Test-MarkdownStructure.ps1 -PluginPath omanfo
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

function Write-ValidationWarning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

# Resolve plugin path
$pluginDir = if ([System.IO.Path]::IsPathRooted($PluginPath)) {
    $PluginPath
} else {
    # Get repo root (3 levels up from scripts/validation/)
    $repoRoot = Join-Path $PSScriptRoot "../../.." | Resolve-Path -ErrorAction Stop
    Join-Path $repoRoot $PluginPath | Resolve-Path -ErrorAction Stop
}

Write-Host "`n🔍 Validating markdown structure for: $pluginDir`n" -ForegroundColor Cyan

# Load manifest
$manifestPath = Join-Path $pluginDir "manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-ValidationError "manifest.json not found at: $manifestPath"
    exit 1
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

# Check if evaluations section exists
if (-not $manifest.evaluations) {
    Write-ValidationWarning "manifest.json has no evaluations section"
    exit 0
}

$evalPath = Join-Path $pluginDir $manifest.evaluations.path
if (-not (Test-Path $evalPath)) {
    Write-ValidationWarning "Evaluations directory not found: $evalPath"
    exit 0
}

# Get all eval files
$evalFiles = @(Get-ChildItem -Path $evalPath -Filter "*.eval.md" -File | Sort-Object Name)

if ($evalFiles.Count -eq 0) {
    Write-ValidationWarning "No evaluation files found in: $evalPath"
    exit 0
}

Write-Host "Validating $($evalFiles.Count) evaluation files:`n" -ForegroundColor Cyan

foreach ($file in $evalFiles) {
    $content = Get-Content $file.FullName -Raw
    $hasErrors = $false
    
    Write-Host "Checking $($file.Name)..." -ForegroundColor Cyan
    
    # Check for priority indicator
    if ($content -match '\*\*Priority:\*\*\s*[🔴🟡🟢]') {
        Write-Host "  ✓ Has priority indicator" -ForegroundColor Gray
    } else {
        Write-ValidationError "  $($file.Name): Missing priority indicator"
        $hasErrors = $true
    }
    
    # Check for time estimate
    if ($content -match '\*\*Time:\*\*\s*\d+\s*(minutes?|hours?)') {
        Write-Host "  ✓ Has time estimate" -ForegroundColor Gray
    } else {
        Write-ValidationError "  $($file.Name): Missing time estimate"
        $hasErrors = $true
    }
    
    # Check for ## Objective section
    if ($content -match '##\s+Objective') {
        Write-Host "  ✓ Has Objective section" -ForegroundColor Gray
    } else {
        Write-ValidationError "  $($file.Name): Missing ## Objective section"
        $hasErrors = $true
    }
    
    # Check for ## Test Steps or ## Setup section
    if ($content -match '##\s+(Test Steps|Setup)') {
        Write-Host "  ✓ Has Test Steps or Setup section" -ForegroundColor Gray
    } else {
        Write-ValidationError "  $($file.Name): Missing ## Test Steps or ## Setup section"
        $hasErrors = $true
    }
    
    if (-not $hasErrors) {
        Write-ValidationSuccess "$($file.Name) structure is valid"
    }
    Write-Host ""
}

Write-Host "" -NoNewline
if ($script:exitCode -eq 0) {
    Write-Host "✅ Markdown structure validation passed for all files" -ForegroundColor Green
} else {
    Write-Host "❌ Markdown structure validation failed" -ForegroundColor Red
}

exit $script:exitCode
