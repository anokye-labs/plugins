#!/usr/bin/env pwsh
<#
.SYNOPSIS
    E2E tests for issue creation capabilities via CLI provider (copilot or claude).

.DESCRIPTION
    Tests creating issues with types through AI CLI prompts and verifies
    state via GitHub API. Requires a supported CLI provider, gh authenticated, and network access.

.NOTES
    Dependencies: copilot or claude CLI on PATH, gh authenticated
    Environment: $env:E2E_TEST_REPO or defaults to anokye-labs/plugins
                 $env:E2E_CLI_PROVIDER or defaults to copilot
#>

[CmdletBinding()]
param()

BeforeAll {
    # Configuration
    $script:TestRepo = $env:E2E_TEST_REPO ?? "anokye-labs/plugins"
    $script:RunId = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:CreatedIssues = @()

    # Load shared CLI test harness
    $harnessPath = Join-Path $PSScriptRoot '..' '..' '..' 'shared' 'CLITestHarness' 'CLITestHarness.psm1'
    if (Test-Path $harnessPath) {
        Import-Module $harnessPath -Force
    }

    # Determine provider from environment (set by Run-E2ETests.ps1 or manually)
    $script:Provider = $env:E2E_CLI_PROVIDER ?? 'copilot'

    # Verify prerequisites
    $providerCheck = Test-ProviderAvailable -Provider $script:Provider -SkipAuthCheck
    if (-not $providerCheck.Available) {
        throw "$script:Provider CLI not found on PATH. Install from: $($providerCheck.InstallUrl)"
    }

    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghCmd) {
        throw "GitHub CLI (gh) not found on PATH. Install from: https://cli.github.com"
    }
    
    # Verify gh authentication
    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI not authenticated. Run: gh auth login"
    }
    
    # Parse repo owner and name
    $repoParts = $script:TestRepo -split '/'
    $script:Owner = $repoParts[0]
    $script:Repo = $repoParts[1]
    
    Write-Host "🧪 E2E Test Configuration:" -ForegroundColor Cyan
    Write-Host "   Repository: $script:TestRepo" -ForegroundColor Gray
    Write-Host "   Provider: $script:Provider" -ForegroundColor Gray
    Write-Host "   Run ID: $script:RunId" -ForegroundColor Gray
    Write-Host ""
}

Describe "Issue Creation E2E Tests" {
    Context "Create Task Issue" {
        It "Should create a Task issue via CLI prompt" {
            $title = "E2E-$script:RunId: Test Task Creation"
            $prompt = "Create a Task issue titled '$title' in $script:TestRepo with body 'Test task for E2E validation'"
            
            # Execute copilot command
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            # Look for issue number in output (format: #123)
            $issueMatch = $output -match '#(\d+)'
            $issueMatch | Should -Be $true -Because "Copilot should create issue and report number"
            
            if ($issueMatch) {
                $issueNum = $matches[1]
                $script:CreatedIssues += $issueNum
                
                # Verify issue exists via API
                Start-Sleep -Seconds 2  # Brief delay for API consistency
                $issueJson = gh api "repos/$script:Owner/$script:Repo/issues/$issueNum" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $issue = $issueJson | ConvertFrom-Json
                    $issue.title | Should -Be $title
                    $issue.state | Should -Be "open"
                }
            }
        }
    }
    
    Context "Create Bug Issue" {
        It "Should create a Bug issue via CLI prompt" {
            $title = "E2E-$script:RunId: Test Bug Report"
            $prompt = "Create a Bug issue titled '$title' in $script:TestRepo describing a test bug for E2E validation"
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $issueMatch = $output -match '#(\d+)'
            $issueMatch | Should -Be $true
            
            if ($issueMatch) {
                $issueNum = $matches[1]
                $script:CreatedIssues += $issueNum
                
                Start-Sleep -Seconds 2
                $issueJson = gh api "repos/$script:Owner/$script:Repo/issues/$issueNum" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $issue = $issueJson | ConvertFrom-Json
                    $issue.title | Should -Be $title
                }
            }
        }
    }
    
    Context "Create Feature Issue" {
        It "Should create a Feature issue via CLI prompt" {
            $title = "E2E-$script:RunId: Test Feature Creation"
            $prompt = "Create a Feature issue titled '$title' in $script:TestRepo with description 'Test feature for E2E validation'"
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $issueMatch = $output -match '#(\d+)'
            $issueMatch | Should -Be $true
            
            if ($issueMatch) {
                $issueNum = $matches[1]
                $script:CreatedIssues += $issueNum
                
                Start-Sleep -Seconds 2
                $issueJson = gh api "repos/$script:Owner/$script:Repo/issues/$issueNum" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $issue = $issueJson | ConvertFrom-Json
                    $issue.title | Should -Be $title
                }
            }
        }
    }
    
    Context "Create Epic Issue" {
        It "Should create an Epic issue via CLI prompt" {
            $title = "E2E-$script:RunId: Test Epic Creation"
            $prompt = "Create an Epic issue titled '$title' in $script:TestRepo describing a test epic for E2E validation"
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $issueMatch = $output -match '#(\d+)'
            $issueMatch | Should -Be $true
            
            if ($issueMatch) {
                $issueNum = $matches[1]
                $script:CreatedIssues += $issueNum
                
                Start-Sleep -Seconds 2
                $issueJson = gh api "repos/$script:Owner/$script:Repo/issues/$issueNum" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $issue = $issueJson | ConvertFrom-Json
                    $issue.title | Should -Be $title
                }
            }
        }
    }
    
    Context "Batch Issue Creation" {
        It "Should create multiple issues in one prompt" {
            $prompt = @"
Create three Task issues in $script:TestRepo with the prefix 'E2E-$script:RunId: Batch Test':
1. Task 1 - First test task
2. Task 2 - Second test task  
3. Task 3 - Third test task
"@
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            # Look for multiple issue numbers
            $allMatches = [regex]::Matches($output, '#(\d+)')
            $allMatches.Count | Should -BeGreaterThan 0 -Because "Should create at least one issue"
            
            # Track all created issues for cleanup
            foreach ($match in $allMatches) {
                $script:CreatedIssues += $match.Groups[1].Value
            }
        }
    }
}

AfterAll {
    # Cleanup: Close all created test issues
    Write-Host "`n🧹 Cleaning up test issues..." -ForegroundColor Cyan
    
    foreach ($issueNum in $script:CreatedIssues) {
        try {
            Write-Host "   Closing issue #$issueNum..." -ForegroundColor Gray
            gh api "repos/$script:Owner/$script:Repo/issues/$issueNum" `
                -X PATCH `
                -f state=closed `
                -f state_reason=not_planned `
                2>&1 | Out-Null
        }
        catch {
            Write-Host "   ⚠️  Failed to close issue #$issueNum" -ForegroundColor Yellow
        }
    }
    
    Write-Host "✅ Cleanup complete. Closed $($script:CreatedIssues.Count) test issues." -ForegroundColor Green
}
