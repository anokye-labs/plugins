#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs E2E capability tests for the Omanfo plugin.

.DESCRIPTION
    Executes all E2E test suites that exercise the Omanfo plugin through
    CLI commands against a live GitHub repository. Supports both GitHub
    Copilot CLI and Claude Code CLI via the -Provider parameter.

.PARAMETER TestSuite
    Specific test suite to run. If not specified, runs all tests.
    Valid values: IssueCreation, Hierarchy, StatusReporting, PRWorkflow, FullWorkflow, All

.PARAMETER Provider
    CLI provider to test against. Valid values: copilot, claude, all.
    Default: copilot (for backward compatibility).
    When 'all' is specified, runs tests against each available provider.

.PARAMETER Repository
    Target repository for tests. Defaults to $env:E2E_TEST_REPO or anokye-labs/plugins.

.PARAMETER OutputFormat
    Pester output format. Valid values: Normal, Detailed, Diagnostic, Minimal.
    Default: Detailed

.EXAMPLE
    ./Run-E2ETests.ps1
    Runs all E2E test suites with Copilot CLI (default).

.EXAMPLE
    ./Run-E2ETests.ps1 -Provider claude -TestSuite IssueCreation
    Runs issue creation tests against Claude Code CLI.

.EXAMPLE
    ./Run-E2ETests.ps1 -Provider all -TestSuite StatusReporting
    Runs status reporting tests against all available providers.

.EXAMPLE
    ./Run-E2ETests.ps1 -TestSuite IssueCreation -Repository "my-org/my-repo"
    Runs only issue creation tests against a specific repository.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('IssueCreation', 'Hierarchy', 'StatusReporting', 'PRWorkflow', 'FullWorkflow', 'All')]
    [string]$TestSuite = 'All',
    
    [Parameter()]
    [ValidateSet('copilot', 'claude', 'all')]
    [string]$Provider = 'copilot',
    
    [Parameter()]
    [string]$Repository,
    
    [Parameter()]
    [ValidateSet('Normal', 'Detailed', 'Diagnostic', 'Minimal')]
    [string]$OutputFormat = 'Detailed'
)

$ErrorActionPreference = 'Stop'

# Resolve test directory and load shared harness
$testDir = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$harnessPath = Join-Path (Split-Path $testDir -Parent | Split-Path -Parent | Split-Path -Parent) 'shared' 'CLITestHarness' 'CLITestHarness.psm1'
if (Test-Path $harnessPath) {
    Import-Module $harnessPath -Force
}

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Omanfo Plugin E2E Tests                                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verify prerequisites
Write-Host "Verifying prerequisites..." -ForegroundColor Cyan

# Determine which providers to test
$providersToTest = @()
if ($Provider -eq 'all') {
    if (Get-Command 'copilot' -ErrorAction SilentlyContinue) { $providersToTest += 'copilot' }
    if (Get-Command 'claude' -ErrorAction SilentlyContinue) { $providersToTest += 'claude' }
    if ($providersToTest.Count -eq 0) {
        Write-Host "No CLI providers found on PATH (tried: copilot, claude)" -ForegroundColor Red
        exit 1
    }
    Write-Host "Providers available: $($providersToTest -join ', ')" -ForegroundColor Green
    if ($providersToTest -contains 'claude') {
        Write-Host "Note: Existing E2E suites still invoke 'copilot -p' directly; Claude runs may fail until suites are migrated to the shared harness." -ForegroundColor Yellow
    }
}
else {
    $providerCmd = Get-Command $Provider -ErrorAction SilentlyContinue
    if (-not $providerCmd) {
        Write-Host "$Provider CLI not found on PATH" -ForegroundColor Red
        if ($Provider -eq 'copilot') {
            Write-Host "   Install from: https://github.com/github/copilot-cli" -ForegroundColor Yellow
        }
        elseif ($Provider -eq 'claude') {
            Write-Host "   Install from: https://docs.anthropic.com/en/docs/claude-code" -ForegroundColor Yellow
        }
        exit 1
    }
    $providersToTest += $Provider
    Write-Host "Provider: $Provider" -ForegroundColor Green
}

$ghCmd = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghCmd) {
    Write-Host "GitHub CLI (gh) not found on PATH" -ForegroundColor Red
    Write-Host "   Install from: https://cli.github.com" -ForegroundColor Yellow
    exit 1
}
$ghVersion = (gh --version | Select-Object -First 1) -replace 'gh version ', ''
Write-Host "GitHub CLI: $ghVersion" -ForegroundColor Green

# Verify gh authentication
$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub CLI not authenticated" -ForegroundColor Red
    Write-Host "   Run: gh auth login" -ForegroundColor Yellow
    exit 1
}
Write-Host "GitHub CLI authenticated" -ForegroundColor Green

# Check Pester
$pesterModule = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pesterModule) {
    Write-Host "Pester not found, installing..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
    Import-Module Pester -Force
    $pesterModule = Get-Module Pester
}
Write-Host "Pester: $($pesterModule.Version)" -ForegroundColor Green

Write-Host ""

# Configure test repository
if ($Repository) {
    $env:E2E_TEST_REPO = $Repository
}
$testRepo = $env:E2E_TEST_REPO ?? "anokye-labs/plugins"

# E2E_CLI_PROVIDER is set per-provider inside the loop below

Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "   Repository: $testRepo" -ForegroundColor Gray
Write-Host "   Provider(s): $($providersToTest -join ', ')" -ForegroundColor Gray
Write-Host "   Test Suite: $TestSuite" -ForegroundColor Gray
Write-Host "   Output Format: $OutputFormat" -ForegroundColor Gray
Write-Host ""

# Determine which test files to run
$testFiles = @()
switch ($TestSuite) {
    'IssueCreation' {
        $testFiles += Join-Path $testDir "IssueCreation.e2e.Tests.ps1"
    }
    'Hierarchy' {
        $testFiles += Join-Path $testDir "Hierarchy.e2e.Tests.ps1"
    }
    'StatusReporting' {
        $testFiles += Join-Path $testDir "StatusReporting.e2e.Tests.ps1"
    }
    'PRWorkflow' {
        $testFiles += Join-Path $testDir "PRWorkflow.e2e.Tests.ps1"
    }
    'FullWorkflow' {
        $testFiles += Join-Path $testDir "FullWorkflow.e2e.Tests.ps1"
    }
    'All' {
        $testFiles += Join-Path $testDir "IssueCreation.e2e.Tests.ps1"
        $testFiles += Join-Path $testDir "Hierarchy.e2e.Tests.ps1"
        $testFiles += Join-Path $testDir "StatusReporting.e2e.Tests.ps1"
        $testFiles += Join-Path $testDir "PRWorkflow.e2e.Tests.ps1"
        $testFiles += Join-Path $testDir "FullWorkflow.e2e.Tests.ps1"
    }
}

# Verify test files exist
foreach ($file in $testFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "❌ Test file not found: $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Running $($testFiles.Count) test suite(s) against $($providersToTest.Count) provider(s)..." -ForegroundColor Cyan
Write-Host ""

$totalPassed = 0
$totalFailed = 0
$totalSkipped = 0
$totalTests = 0

foreach ($currentProvider in $providersToTest) {
    Write-Host "" -ForegroundColor Cyan
    Write-Host "--- Provider: $currentProvider ---" -ForegroundColor Cyan
    Write-Host ""
    
    $env:E2E_CLI_PROVIDER = $currentProvider
    
    # Configure Pester
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = $testFiles
    $pesterConfig.Output.Verbosity = $OutputFormat
    $pesterConfig.Should.ErrorAction = 'Continue'
    
    try {
        $result = Invoke-Pester -Configuration $pesterConfig
        
        $totalPassed += $result.PassedCount
        $totalFailed += $result.FailedCount
        $totalSkipped += $result.SkippedCount
        $totalTests += $result.TotalCount
        
        Write-Host "  [$currentProvider] Passed: $($result.PassedCount) | Failed: $($result.FailedCount) | Skipped: $($result.SkippedCount)" -ForegroundColor Gray
    }
    catch {
        Write-Host "  [$currentProvider] Test execution failed: $_" -ForegroundColor Red
        $totalFailed++
    }
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Test Summary                                           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Provider(s): $($providersToTest -join ', ')" -ForegroundColor Gray

if ($totalFailed -eq 0) {
    Write-Host "   All tests passed!" -ForegroundColor Green
    Write-Host "   Total: $totalTests" -ForegroundColor Gray
    Write-Host "   Passed: $totalPassed" -ForegroundColor Green
    Write-Host "   Skipped: $totalSkipped" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "   Some tests failed" -ForegroundColor Red
    Write-Host "   Total: $totalTests" -ForegroundColor Gray
    Write-Host "   Passed: $totalPassed" -ForegroundColor Green
    Write-Host "   Failed: $totalFailed" -ForegroundColor Red
    Write-Host "   Skipped: $totalSkipped" -ForegroundColor Yellow
    exit 1
}
