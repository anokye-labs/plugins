#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that all PowerShell scripts have corresponding unit test coverage.

.DESCRIPTION
    This script ensures that every .ps1 file in the plugin's skills/okyerema/scripts/ directory
    has at least one Describe block in the unit tests. This prevents merging code without tests.
    
    The validation works by:
    1. Enumerating all .ps1 files in skills/okyerema/scripts/
    2. Parsing all Describe blocks in tests/omanfo/unit/*.Unit.Tests.ps1
    3. Failing if any script name doesn't appear in a Describe block

.PARAMETER PluginPath
    Path to the plugin directory (e.g., omanfo or okyeame). Defaults to omanfo.

.EXAMPLE
    ./Test-ScriptTestCoverage.ps1 -PluginPath omanfo
    
.NOTES
    This script is used in CI/CD to enforce test coverage requirements.
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

Write-Host "`n🔍 Validating test coverage for: $pluginDir`n" -ForegroundColor Cyan

# Build paths
$scriptsDir = Join-Path $pluginDir "skills/okyerema/scripts"
$testsDir = Join-Path $repoRoot "tests/$PluginPath/unit"

# Validate directories exist
if (-not (Test-Path $scriptsDir)) {
    Write-ValidationError "Scripts directory not found: $scriptsDir"
    exit $script:exitCode
}

if (-not (Test-Path $testsDir)) {
    Write-ValidationError "Unit tests directory not found: $testsDir"
    exit $script:exitCode
}

# Step 1: Get all script files
$scriptFiles = Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -File -ErrorAction Stop
if ($scriptFiles.Count -eq 0) {
    Write-ValidationWarning "No PowerShell scripts found in $scriptsDir"
    exit 0
}

$scriptNames = $scriptFiles | ForEach-Object { $_.BaseName }
Write-Host "Found $($scriptNames.Count) scripts to validate`n" -ForegroundColor Cyan

# Step 2: Parse all Describe blocks from unit tests
$testFiles = Get-ChildItem -Path $testsDir -Filter "*.Unit.Tests.ps1" -File -ErrorAction Stop
if ($testFiles.Count -eq 0) {
    Write-ValidationError "No unit test files (*.Unit.Tests.ps1) found in $testsDir"
    exit 1
}

Write-Host "Scanning $($testFiles.Count) unit test file(s)`n" -ForegroundColor Cyan

$testedScripts = @()
foreach ($testFile in $testFiles) {
    $content = Get-Content $testFile.FullName -Raw
    # Match Describe blocks - pattern: Describe "ScriptName" {
    $matches = [regex]::Matches($content, 'Describe\s+"([^"]+)"')
    foreach ($match in $matches) {
        $describeName = $match.Groups[1].Value
        $testedScripts += $describeName
    }
}

$testedScripts = $testedScripts | Sort-Object -Unique
Write-Host "Found $($testedScripts.Count) Describe blocks in unit tests`n" -ForegroundColor Cyan

# Step 3: Check coverage
$untestedScripts = $scriptNames | Where-Object { $_ -notin $testedScripts }

if ($untestedScripts.Count -eq 0) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-ValidationSuccess "All $($scriptNames.Count) scripts have test coverage!"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
    Write-Host "❌ COVERAGE VALIDATION FAILED" -ForegroundColor Red
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
    Write-Host ""
    Write-Host "The following scripts lack unit test coverage:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($script in $untestedScripts) {
        Write-ValidationError "  $script.ps1"
    }
    Write-Host ""
    Write-Host "To fix this issue:" -ForegroundColor Cyan
    Write-Host "  1. Add a Describe block for each missing script in tests/$PluginPath/unit/*.Unit.Tests.ps1" -ForegroundColor Gray
    Write-Host "  2. Example: Describe `"$($untestedScripts[0])`" { ... }" -ForegroundColor Gray
    Write-Host "  3. Run unit tests locally: pwsh tests/$PluginPath/Run-LocalTests.ps1 -TestLevel Unit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Coverage Report:" -ForegroundColor Cyan
    Write-Host "  Scripts with tests: $($scriptNames.Count - $untestedScripts.Count)" -ForegroundColor Green
    Write-Host "  Scripts without tests: $($untestedScripts.Count)" -ForegroundColor Red
    Write-Host "  Coverage: $([math]::Round((($scriptNames.Count - $untestedScripts.Count) / $scriptNames.Count) * 100, 1))%" -ForegroundColor Yellow
    Write-Host ""
    $script:exitCode = 1
}

exit $script:exitCode
