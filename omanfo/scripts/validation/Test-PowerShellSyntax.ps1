#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates PowerShell syntax for all .ps1 files in a plugin.

.DESCRIPTION
    This script parses all PowerShell files in the plugin to ensure they have valid syntax.
    It reports any parsing errors found.

.PARAMETER PluginPath
    Path to the plugin directory (e.g., omanfo or okyeame). Defaults to omanfo.

.EXAMPLE
    ./Test-PowerShellSyntax.ps1 -PluginPath omanfo
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

Write-Host "`n🔍 Validating PowerShell syntax for: $pluginDir`n" -ForegroundColor Cyan

# Find all .ps1 files
$psFiles = Get-ChildItem -Path $pluginDir -Filter "*.ps1" -Recurse -File

if ($psFiles.Count -eq 0) {
    Write-Host "⚠️  No PowerShell files found" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($psFiles.Count) PowerShell files to validate`n" -ForegroundColor Cyan

$errorCount = 0
foreach ($file in $psFiles) {
    $relativePath = $file.FullName.Substring($pluginDir.Length + 1)
    
    try {
        # Parse the file
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName,
            [ref]$null,
            [ref]$null
        )
        Write-ValidationSuccess $relativePath
    }
    catch {
        Write-ValidationError "$relativePath - $($_.Exception.Message)"
        $errorCount++
    }
}

Write-Host "`n" -NoNewline
if ($errorCount -eq 0) {
    Write-Host "✅ All $($psFiles.Count) PowerShell files have valid syntax" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ $errorCount PowerShell file(s) have syntax errors" -ForegroundColor Red
    exit 1
}
