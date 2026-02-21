#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Master test runner for Omanfo plugin tests.

.DESCRIPTION
    Runs Pester tests at different levels (Unit, Smoke, E2E, or All).
    Auto-installs Pester 5.x if not present.
    Discovers and runs test files by level based on naming conventions:
    - Unit tests: *.Unit.Tests.ps1
    - Smoke tests: *.Smoke.Tests.ps1 or files in Smoke/ subdirectory
    - E2E tests: *.E2E.Tests.ps1 or files in E2E/ subdirectory

.PARAMETER TestLevel
    The level of tests to run: Unit, Smoke, E2E, or All (default: All)

.PARAMETER TestRepo
    Repository to use for E2E tests (default: anokye-labs/plugins)

.EXAMPLE
    ./Run-LocalTests.ps1 -TestLevel Smoke

.EXAMPLE
    ./Run-LocalTests.ps1 -TestLevel E2E -TestRepo myorg/myrepo

.EXAMPLE
    ./Run-LocalTests.ps1 -TestLevel All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Unit', 'Smoke', 'E2E', 'All')]
    [string]$TestLevel = 'All',

    [Parameter()]
    [string]$TestRepo = 'anokye-labs/plugins'
)

# Do NOT use Set-StrictMode per requirements
$ErrorActionPreference = 'Stop'

# Ensure Pester 5.x is available
function Ensure-Pester {
    Write-Host "Checking for Pester 5.x..." -ForegroundColor Cyan
    
    $pester = Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ge '5.0.0' }
    
    if (-not $pester) {
        Write-Host "Pester 5.x not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck
            Write-Host "Pester 5.x installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install Pester 5.x: $_"
            exit 1
        }
    }
    else {
        Write-Host "Pester $($pester[0].Version) found." -ForegroundColor Green
    }
    
    # Import Pester
    Import-Module Pester -MinimumVersion 5.0.0 -Force
}

# Discover test files by level
function Get-TestFiles {
    param(
        [string]$Level,
        [string]$TestsPath
    )
    
    $testFiles = @()
    
    switch ($Level) {
        'Unit' {
            # Find files matching *.Unit.Tests.ps1
            $unitTests = Get-ChildItem -Path $TestsPath -Filter "*.Unit.Tests.ps1" -Recurse -File -ErrorAction SilentlyContinue
            $testFiles += $unitTests
        }
        'Smoke' {
            # Find files matching *.Smoke.Tests.ps1 (recursively)
            $smokeTests = Get-ChildItem -Path $TestsPath -Filter "*.Smoke.Tests.ps1" -Recurse -File -ErrorAction SilentlyContinue
            
            # Also find *.Tests.ps1 in Smoke/ subdirectory (but not *.Smoke.Tests.ps1 to avoid duplicates)
            $smokePath = Join-Path $TestsPath "Smoke"
            if (Test-Path $smokePath) {
                $smokeSubdirTests = Get-ChildItem -Path $smokePath -Filter "*.Tests.ps1" -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notlike "*.Smoke.Tests.ps1" }
                $smokeTests += $smokeSubdirTests
            }
            $testFiles += $smokeTests
        }
        'E2E' {
            # Find files matching *.E2E.Tests.ps1 (recursively)
            $e2eTests = Get-ChildItem -Path $TestsPath -Filter "*.E2E.Tests.ps1" -Recurse -File -ErrorAction SilentlyContinue
            
            # Also find *.Tests.ps1 in E2E/ subdirectory (but not *.E2E.Tests.ps1 to avoid duplicates)
            $e2ePath = Join-Path $TestsPath "E2E"
            if (Test-Path $e2ePath) {
                $e2eSubdirTests = Get-ChildItem -Path $e2ePath -Filter "*.Tests.ps1" -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notlike "*.E2E.Tests.ps1" }
                $e2eTests += $e2eSubdirTests
            }
            $testFiles += $e2eTests
        }
        'All' {
            # Get all test levels
            $testFiles += Get-TestFiles -Level 'Unit' -TestsPath $TestsPath
            $testFiles += Get-TestFiles -Level 'Smoke' -TestsPath $TestsPath
            $testFiles += Get-TestFiles -Level 'E2E' -TestsPath $TestsPath
        }
    }
    
    return $testFiles | Select-Object -Unique
}

# Run automated E2E tests (Node.js/TypeScript)
function Invoke-AutomatedE2ETests {
    param(
        [string]$TestsPath,
        [string]$TestRepo
    )
    
    $automatedPath = Join-Path $TestsPath "e2e/automated"
    
    if (-not (Test-Path $automatedPath)) {
        Write-Host "No automated E2E tests found at: $automatedPath" -ForegroundColor Gray
        return $null
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Running Automated E2E Tests (SDK)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Check for Node.js
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Write-Warning "Node.js not found. Skipping automated E2E tests."
        Write-Host "Install Node.js from: https://nodejs.org" -ForegroundColor Yellow
        return $null
    }
    
    $nodeVersion = node --version
    Write-Host "Node.js: $nodeVersion" -ForegroundColor Green
    
    # Check for npm
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmCmd) {
        Write-Warning "npm not found. Skipping automated E2E tests."
        Write-Host "npm is typically installed with Node.js" -ForegroundColor Yellow
        return $null
    }
    
    # Check for gh CLI
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghCmd) {
        Write-Warning "GitHub CLI (gh) not found. Skipping automated E2E tests."
        Write-Host "Install from: https://cli.github.com" -ForegroundColor Yellow
        return $null
    }
    
    # Run validation script to check all prerequisites
    Write-Host "Validating prerequisites..." -ForegroundColor Cyan
    Push-Location $automatedPath
    try {
        $validationOutput = node validate-setup.mjs 2>&1
        $validationExitCode = $LASTEXITCODE
        
        # Show validation output
        $validationOutput | ForEach-Object { Write-Host $_ }
        
        if ($validationExitCode -ne 0) {
            Write-Warning "Prerequisite validation failed. Skipping automated E2E tests."
            Pop-Location
            return $null
        }
    }
    catch {
        Write-Warning "Failed to run validation: $_"
        Pop-Location
        return $null
    }
    finally {
        if ((Get-Location).Path -eq $automatedPath) {
            Pop-Location
        }
    }
    
    # Check if dependencies are installed
    $nodeModulesPath = Join-Path $automatedPath "node_modules"
    if (-not (Test-Path $nodeModulesPath)) {
        Write-Host "Installing dependencies..." -ForegroundColor Cyan
        Push-Location $automatedPath
        try {
            npm install --silent
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to install dependencies"
            }
            Write-Host "✓ Dependencies installed" -ForegroundColor Green
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Host "✓ Dependencies already installed" -ForegroundColor Green
    }
    
    # Set environment variables
    $env:E2E_TEST_REPO = $TestRepo
    
    # Find all *.e2e.ts test files
    $testFiles = Get-ChildItem -Path $automatedPath -Filter "*.e2e.ts" -File | 
        Where-Object { $_.Name -notlike "copilot-harness.ts" }
    
    if ($testFiles.Count -eq 0) {
        Write-Warning "No automated E2E test files found"
        return $null
    }
    
    Write-Host "Found $($testFiles.Count) automated test(s):`n" -ForegroundColor Green
    foreach ($file in $testFiles) {
        Write-Host "  - $($file.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Run each test file
    $results = @{
        Total = 0
        Passed = 0
        Failed = 0
    }
    
    Push-Location $automatedPath
    try {
        foreach ($testFile in $testFiles) {
            $results.Total++
            Write-Host "`n▶ Running $($testFile.Name)..." -ForegroundColor Cyan
            
            $output = node --loader ts-node/esm $testFile.Name 2>&1
            $exitCode = $LASTEXITCODE
            
            # Display output
            $output | ForEach-Object { Write-Host $_ }
            
            if ($exitCode -eq 0) {
                $results.Passed++
                Write-Host "✓ $($testFile.Name) PASSED" -ForegroundColor Green
            }
            else {
                $results.Failed++
                Write-Host "✗ $($testFile.Name) FAILED" -ForegroundColor Red
            }
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Automated E2E Test Summary" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "  Total: $($results.Total)" -ForegroundColor White
    Write-Host "  Passed: $($results.Passed)" -ForegroundColor Green
    Write-Host "  Failed: $($results.Failed)" -ForegroundColor $(if ($results.Failed -gt 0) { 'Red' } else { 'Green' })
    Write-Host ""
    
    return $results
}

# Main execution
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Omanfo Plugin Test Runner" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Ensure Pester is available
    Ensure-Pester
    
    # Get the tests directory path
    $scriptPath = $PSScriptRoot
    if (-not $scriptPath) {
        $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $testsPath = $scriptPath
    
    Write-Host "Test Level: $TestLevel" -ForegroundColor Cyan
    Write-Host "Test Repo: $TestRepo" -ForegroundColor Cyan
    Write-Host "Tests Path: $testsPath`n" -ForegroundColor Cyan
    
    # Store test repo for E2E tests
    $env:TEST_REPO = $TestRepo
    
    # Discover test files
    Write-Host "Discovering test files..." -ForegroundColor Cyan
    $testFiles = Get-TestFiles -Level $TestLevel -TestsPath $testsPath
    
    if ($testFiles.Count -eq 0) {
        Write-Warning "No test files found for level: $TestLevel"
        Write-Host "`nNote: Expected test file naming conventions:" -ForegroundColor Yellow
        Write-Host "  - Unit tests: *.Unit.Tests.ps1" -ForegroundColor Yellow
        Write-Host "  - Smoke tests: *.Smoke.Tests.ps1 or Smoke/*.Tests.ps1" -ForegroundColor Yellow
        Write-Host "  - E2E tests: *.E2E.Tests.ps1 or E2E/*.Tests.ps1" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found $($testFiles.Count) test file(s):`n" -ForegroundColor Green
    foreach ($file in $testFiles) {
        Write-Host "  - $($file.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Run tests
    Write-Host "Running tests...`n" -ForegroundColor Cyan
    
    $config = New-PesterConfiguration
    $config.Run.Path = $testFiles.FullName
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    
    $result = Invoke-Pester -Configuration $config
    
    # Run automated E2E tests if E2E level is requested
    $automatedResults = $null
    if ($TestLevel -eq 'E2E' -or $TestLevel -eq 'All') {
        $automatedResults = Invoke-AutomatedE2ETests -TestsPath $testsPath -TestRepo $TestRepo
    }
    
    # Print summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Create summary table
    $summary = @()
    
    # Group results by test level
    $levels = @()
    if ($TestLevel -eq 'All') {
        $levels = @('Unit', 'Smoke', 'E2E')
    }
    else {
        $levels = @($TestLevel)
    }
    
    foreach ($level in $levels) {
        $levelFiles = Get-TestFiles -Level $level -TestsPath $testsPath
        
        if ($levelFiles.Count -gt 0) {
            # Count tests for this level from the results
            $levelTests = $result.Tests | Where-Object { 
                $testFile = $_.ScriptBlock.File
                $levelFiles.FullName -contains $testFile
            }
            
            $passed = ($levelTests | Where-Object { $_.Result -eq 'Passed' }).Count
            $failed = ($levelTests | Where-Object { $_.Result -eq 'Failed' }).Count
            $skipped = ($levelTests | Where-Object { $_.Result -eq 'Skipped' }).Count
            $total = $levelTests.Count
            
            $summary += [PSCustomObject]@{
                Level   = $level
                Total   = $total
                Passed  = $passed
                Failed  = $failed
                Skipped = $skipped
            }
        }
    }
    
    # Display summary table
    if ($summary.Count -gt 0) {
        $summary | Format-Table -AutoSize
    }
    
    # Overall results
    Write-Host "Pester Tests:" -ForegroundColor Cyan
    Write-Host "  Total Tests: $($result.TotalCount)" -ForegroundColor White
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Duration: $($result.Duration)`n" -ForegroundColor White
    
    # Include automated test results if available
    $totalFailed = $result.FailedCount
    if ($automatedResults) {
        Write-Host "Automated E2E Tests:" -ForegroundColor Cyan
        Write-Host "  Total: $($automatedResults.Total)" -ForegroundColor White
        Write-Host "  Passed: $($automatedResults.Passed)" -ForegroundColor Green
        Write-Host "  Failed: $($automatedResults.Failed)" -ForegroundColor $(if ($automatedResults.Failed -gt 0) { 'Red' } else { 'Green' })
        Write-Host ""
        $totalFailed += $automatedResults.Failed
    }
    
    # Exit with appropriate code
    if ($totalFailed -gt 0) {
        Write-Host "Tests FAILED!" -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "All tests PASSED!" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "Test runner failed: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
