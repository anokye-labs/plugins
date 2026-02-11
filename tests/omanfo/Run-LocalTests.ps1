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
    
    # For E2E tests, also run automated tests if they exist
    $automatedE2EFailed = $false
    if ($TestLevel -eq 'E2E' -or $TestLevel -eq 'All') {
        $automatedE2EPath = Join-Path $testsPath "e2e/automated"
        if (Test-Path $automatedE2EPath) {
            Write-Host "Checking for automated E2E tests...`n" -ForegroundColor Cyan
            
            $packageJsonPath = Join-Path $automatedE2EPath "package.json"
            $testScriptPath = Join-Path $automatedE2EPath "automated-tests.mjs"
            
            if ((Test-Path $packageJsonPath) -and (Test-Path $testScriptPath)) {
                Write-Host "Found automated E2E tests (Copilot SDK)`n" -ForegroundColor Green
                
                # Check if node is available
                $nodeAvailable = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
                
                if ($nodeAvailable) {
                    Write-Host "Running automated E2E tests...`n" -ForegroundColor Cyan
                    
                    Push-Location $automatedE2EPath
                    try {
                        # Install dependencies if needed
                        if (-not (Test-Path "node_modules")) {
                            Write-Host "Installing npm dependencies..." -ForegroundColor Yellow
                            npm install 2>&1 | Out-Null
                            if ($LASTEXITCODE -ne 0) {
                                Write-Warning "Failed to install npm dependencies"
                                $automatedE2EFailed = $true
                            }
                        }
                        
                        if (-not $automatedE2EFailed) {
                            # Run automated tests
                            $env:E2E_TEST_OWNER = $TestRepo.Split('/')[0]
                            $env:E2E_TEST_REPO = $TestRepo.Split('/')[1]
                            
                            Write-Host ""
                            node automated-tests.mjs
                            
                            if ($LASTEXITCODE -ne 0) {
                                Write-Host "`n⚠️  Automated E2E tests failed" -ForegroundColor Yellow
                                $automatedE2EFailed = $true
                            } else {
                                Write-Host "`n✅ Automated E2E tests passed" -ForegroundColor Green
                            }
                        }
                    }
                    catch {
                        Write-Warning "Error running automated E2E tests: $_"
                        $automatedE2EFailed = $true
                    }
                    finally {
                        Pop-Location
                    }
                }
                else {
                    Write-Warning "Node.js not found - skipping automated E2E tests"
                    Write-Host "Install Node.js 18+ to run automated E2E tests" -ForegroundColor Yellow
                }
                
                Write-Host ""
            }
        }
    }
    
    # Discover test files
    Write-Host "Discovering Pester test files..." -ForegroundColor Cyan
    $testFiles = Get-TestFiles -Level $TestLevel -TestsPath $testsPath
    
    if ($testFiles.Count -eq 0) {
        # If no Pester tests but automated E2E ran, that's OK for E2E level
        if ($TestLevel -eq 'E2E' -and -not $automatedE2EFailed) {
            Write-Host "`n✅ Automated E2E tests completed (no Pester E2E tests found)" -ForegroundColor Green
            exit 0
        }
        
        Write-Warning "No test files found for level: $TestLevel"
        Write-Host "`nNote: Expected test file naming conventions:" -ForegroundColor Yellow
        Write-Host "  - Unit tests: *.Unit.Tests.ps1" -ForegroundColor Yellow
        Write-Host "  - Smoke tests: *.Smoke.Tests.ps1 or Smoke/*.Tests.ps1" -ForegroundColor Yellow
        Write-Host "  - E2E tests: *.E2E.Tests.ps1 or E2E/*.Tests.ps1" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found $($testFiles.Count) Pester test file(s):`n" -ForegroundColor Green
    foreach ($file in $testFiles) {
        Write-Host "  - $($file.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Run tests
    Write-Host "Running Pester tests...`n" -ForegroundColor Cyan
    
    $config = New-PesterConfiguration
    $config.Run.Path = $testFiles.FullName
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    
    $result = Invoke-Pester -Configuration $config
    
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
    Write-Host "Overall Pester Results:" -ForegroundColor Cyan
    Write-Host "  Total Tests: $($result.TotalCount)" -ForegroundColor White
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Duration: $($result.Duration)`n" -ForegroundColor White
    
    # Exit with appropriate code (consider both Pester and automated E2E results)
    if ($result.FailedCount -gt 0 -or $automatedE2EFailed) {
        if ($result.FailedCount -gt 0) {
            Write-Host "Pester tests FAILED!" -ForegroundColor Red
        }
        if ($automatedE2EFailed) {
            Write-Host "Automated E2E tests FAILED!" -ForegroundColor Red
        }
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
