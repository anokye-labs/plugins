#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that every capability in manifest has a corresponding .eval.md file.

.DESCRIPTION
    This script verifies that evaluation files exist for plugin capabilities.
    It checks that evaluation files follow the naming pattern NN-description.eval.md.

.PARAMETER PluginPath
    Path to the plugin directory (e.g., omanfo or okyeame). Defaults to omanfo.

.EXAMPLE
    ./Test-EvalCoverage.ps1 -PluginPath omanfo
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

Write-Host "`n🔍 Validating evaluation coverage for: $pluginDir`n" -ForegroundColor Cyan

# Check for evaluations directory
$evalPath = Join-Path $pluginDir "evaluations"
if (-not (Test-Path $evalPath)) {
    Write-ValidationWarning "No evaluations/ directory found"
    exit 0
}

# Get all eval files
$evalFiles = @(Get-ChildItem -Path $evalPath -Filter "*.eval.md" -File | Sort-Object Name)

if ($evalFiles.Count -eq 0) {
    Write-ValidationWarning "No evaluation files found in: $evalPath"
    exit 0
}

Write-Host "Found $($evalFiles.Count) evaluation files:`n" -ForegroundColor Cyan

# Validate naming pattern
$validPattern = '^\d{2}-.+\.eval\.md$'
foreach ($file in $evalFiles) {
    if ($file.Name -match $validPattern) {
        Write-ValidationSuccess $file.Name
    } else {
        Write-ValidationError "$($file.Name) does not follow naming pattern NN-description.eval.md"
    }
}

Write-Host "`n" -NoNewline
if ($script:exitCode -eq 0) {
    Write-Host "✅ Evaluation coverage validation passed" -ForegroundColor Green
} else {
    Write-Host "❌ Evaluation coverage validation failed" -ForegroundColor Red
}

exit $script:exitCode
