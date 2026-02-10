#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs E2E capability tests for the Omanfo plugin.

.DESCRIPTION
    Executes all E2E test suites that exercise the Omanfo plugin through
    copilot CLI commands against a live GitHub repository.

.PARAMETER TestSuite
    Specific test suite to run. If not specified, runs all tests.
    Valid values: IssueCreation, Hierarchy, StatusReporting, PRWorkflow, FullWorkflow, All

.PARAMETER Repository
    Target repository for tests. Defaults to $env:E2E_TEST_REPO or anokye-labs/plugins.

.PARAMETER OutputFormat
    Pester output format. Valid values: Normal, Detailed, Diagnostic, Minimal.
    Default: Detailed

.EXAMPLE
    ./Run-E2ETests.ps1
    Runs all E2E test suites with default configuration.

.EXAMPLE
    ./Run-E2ETests.ps1 -TestSuite IssueCreation -Repository "my-org/my-repo"
    Runs only issue creation tests against a specific repository.

.EXAMPLE
    ./Run-E2ETests.ps1 -TestSuite FullWorkflow -OutputFormat Diagnostic
    Runs full workflow test with diagnostic output.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('IssueCreation', 'Hierarchy', 'StatusReporting', 'PRWorkflow', 'FullWorkflow', 'All')]
    [string]$TestSuite = 'All',
    
    [Parameter()]
    [string]$Repository,
    
    [Parameter()]
    [ValidateSet('Normal', 'Detailed', 'Diagnostic', 'Minimal')]
    [string]$OutputFormat = 'Detailed'
)

$ErrorActionPreference = 'Stop'

# Resolve test directory
$testDir = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Omanfo Plugin E2E Tests                                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verify prerequisites
Write-Host "🔍 Verifying prerequisites..." -ForegroundColor Cyan

$copilotCmd = Get-Command copilot -ErrorAction SilentlyContinue
if (-not $copilotCmd) {
    Write-Host "❌ Copilot CLI not found on PATH" -ForegroundColor Red
    Write-Host "   Install from: https://github.com/github/copilot-cli" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Copilot CLI: $($copilotCmd.Version)" -ForegroundColor Green

$ghCmd = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghCmd) {
    Write-Host "❌ GitHub CLI (gh) not found on PATH" -ForegroundColor Red
    Write-Host "   Install from: https://cli.github.com" -ForegroundColor Yellow
    exit 1
}
$ghVersion = (gh --version | Select-Object -First 1) -replace 'gh version ', ''
Write-Host "✅ GitHub CLI: $ghVersion" -ForegroundColor Green

# Verify gh authentication
$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ GitHub CLI not authenticated" -ForegroundColor Red
    Write-Host "   Run: gh auth login" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ GitHub CLI authenticated" -ForegroundColor Green

# Check Pester
$pesterModule = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pesterModule) {
    Write-Host "⚠️  Pester not found, installing..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
    Import-Module Pester -Force
    $pesterModule = Get-Module Pester
}
Write-Host "✅ Pester: $($pesterModule.Version)" -ForegroundColor Green

Write-Host ""

# Configure test repository
if ($Repository) {
    $env:E2E_TEST_REPO = $Repository
}
$testRepo = $env:E2E_TEST_REPO ?? "anokye-labs/plugins"

Write-Host "📝 Test Configuration:" -ForegroundColor Cyan
Write-Host "   Repository: $testRepo" -ForegroundColor Gray
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

Write-Host "🧪 Running $($testFiles.Count) test suite(s)..." -ForegroundColor Cyan
Write-Host ""

# Configure Pester
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = $testFiles
$pesterConfig.Output.Verbosity = $OutputFormat
$pesterConfig.Should.ErrorAction = 'Continue'

# Run tests
try {
    $result = Invoke-Pester -Configuration $pesterConfig
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         Test Summary                                           ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if ($result.FailedCount -eq 0) {
        Write-Host "✅ All tests passed!" -ForegroundColor Green
        Write-Host "   Total: $($result.TotalCount)" -ForegroundColor Gray
        Write-Host "   Passed: $($result.PassedCount)" -ForegroundColor Green
        Write-Host "   Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
        Write-Host "   Duration: $($result.Duration)" -ForegroundColor Gray
        exit 0
    } else {
        Write-Host "❌ Some tests failed" -ForegroundColor Red
        Write-Host "   Total: $($result.TotalCount)" -ForegroundColor Gray
        Write-Host "   Passed: $($result.PassedCount)" -ForegroundColor Green
        Write-Host "   Failed: $($result.FailedCount)" -ForegroundColor Red
        Write-Host "   Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
        Write-Host "   Duration: $($result.Duration)" -ForegroundColor Gray
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "❌ Test execution failed: $_" -ForegroundColor Red
    exit 1
}
