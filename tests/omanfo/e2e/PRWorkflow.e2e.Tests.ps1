#!/usr/bin/env pwsh
<#
.SYNOPSIS
    E2E tests for PR workflow operations via Copilot CLI.

.DESCRIPTION
    Tests PR status, health checks, timeline queries, and thread operations
    through copilot prompts.

.NOTES
    Dependencies: copilot CLI on PATH, gh authenticated, git configured
    Environment: $env:E2E_TEST_REPO or defaults to anokye-labs/plugins
    Note: Some tests require an existing open PR or will be skipped
#>

[CmdletBinding()]
param()

BeforeAll {
    # Configuration
    $script:TestRepo = $env:E2E_TEST_REPO ?? "anokye-labs/plugins"
    $script:RunId = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:CreatedIssues = @()
    $script:TestPR = $null
    
    # Verify prerequisites
    $copilotCmd = Get-Command copilot -ErrorAction SilentlyContinue
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    
    if (-not $copilotCmd) {
        throw "Copilot CLI not found on PATH"
    }
    
    if (-not $ghCmd) {
        throw "GitHub CLI (gh) not found on PATH"
    }
    
    if (-not $gitCmd) {
        throw "Git not found on PATH"
    }
    
    # Verify gh authentication
    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI not authenticated"
    }
    
    # Parse repo owner and name
    $repoParts = $script:TestRepo -split '/'
    $script:Owner = $repoParts[0]
    $script:Repo = $repoParts[1]
    
    Write-Host "🧪 E2E PR Workflow Test Configuration:" -ForegroundColor Cyan
    Write-Host "   Repository: $script:TestRepo" -ForegroundColor Gray
    Write-Host "   Run ID: $script:RunId" -ForegroundColor Gray
    Write-Host ""
    
    # Try to find an existing open PR for testing
    Write-Host "🔍 Looking for an open PR to test with..." -ForegroundColor Cyan
    $prs = gh pr list --repo $script:TestRepo --limit 1 --json number,title 2>&1
    if ($LASTEXITCODE -eq 0) {
        $prList = $prs | ConvertFrom-Json
        if ($prList.Count -gt 0) {
            $script:TestPR = $prList[0]
            Write-Host "✅ Found PR #$($script:TestPR.number): $($script:TestPR.title)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  No open PRs found. Some tests will be skipped." -ForegroundColor Yellow
        }
    }
}

Describe "PR Workflow E2E Tests" {
    Context "PR Status Queries" {
        It "Should query PR status via copilot" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "What is the status of PR #$prNum in $script:TestRepo?"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(status|state|open|draft|check|review)" -Because "Should report PR status"
        }
        
        It "Should check PR checks status" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "Check CI status for PR #$prNum in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(check|ci|build|test|pass|fail|pending)" -Because "Should report check status"
        }
        
        It "Should query PR approvals" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "How many approvals does PR #$prNum have in $script:TestRepo?"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(approval|review|approve)" -Because "Should report approval status"
        }
    }
    
    Context "PR Health Check" {
        It "Should execute PR health check" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "Run health check for PR #$prNum in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            # Should include health metrics
            $output | Should -Match "(health|thread|check|conflict|review)" -Because "Health check should analyze PR state"
        }
        
        It "Should report PR recommendation" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "Should I merge PR #$prNum in $script:TestRepo?"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(merge|ready|wait|block|approve)" -Because "Should provide merge recommendation"
        }
    }
    
    Context "PR Timeline" {
        It "Should query PR timeline" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "Show timeline for PR #$prNum in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            # Should show events
            $output | Should -Match "(timeline|event|commit|review|comment)" -Because "Timeline should show PR events"
        }
        
        It "Should summarize PR activity" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "Summarize recent activity on PR #$prNum in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Review Thread Operations" {
        It "Should query unresolved threads" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "Show unresolved review threads for PR #$prNum in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(thread|review|unresolved|resolved|comment)" -Because "Should list thread status"
        }
        
        It "Should count threads by severity" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "Analyze review thread severity for PR #$prNum in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should differentiate automated vs human threads" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "How many automated vs human review threads in PR #$prNum in $script:TestRepo?"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(automated|human|bot|thread)" -Because "Should categorize thread sources"
        }
    }
    
    Context "PR Comparison" {
        It "Should compare two PRs" {
            # Get two PRs if available
            $prs = gh pr list --repo $script:TestRepo --limit 2 --json number 2>&1
            if ($LASTEXITCODE -eq 0) {
                $prList = @($prs | ConvertFrom-Json)
                if ($prList.Count -ge 2) {
                    $pr1 = $prList[0].number
                    $pr2 = $prList[1].number
                    $prompt = "Compare PR #$pr1 and PR #$pr2 in $script:TestRepo"
                    
                    $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
                    
                    $output | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
    
    Context "PR Workflow Guidance" {
        It "Should provide next steps for PR" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "What are the next steps for PR #$prNum in $script:TestRepo?"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(next|step|action|need|should)" -Because "Should suggest next actions"
        }
        
        It "Should identify PR blockers" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "What is blocking PR #$prNum from merging in $script:TestRepo?"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "PR Metadata Queries" {
        It "Should find PR by issue number" {
            if ($script:CreatedIssues.Count -gt 0) {
                $issueNum = $script:CreatedIssues[0]
                $prompt = "Find PR associated with issue #$issueNum in $script:TestRepo"
                
                $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
                
                $output | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should list recent PRs" {
            $prompt = "List the 5 most recent PRs in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(PR|pull request|#\d+)" -Because "Should list PR numbers"
        }
        
        It "Should filter PRs by author" {
            $prompt = "Show PRs by copilot[bot] in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "PR Conflict Detection" {
        It "Should check for merge conflicts" -Skip:($null -eq $script:TestPR) {
            $prNum = $script:TestPR.number
            $prompt = "Does PR #$prNum in $script:TestRepo have merge conflicts?"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(conflict|merge|mergeable)" -Because "Should report conflict status"
        }
    }
}

AfterAll {
    # Cleanup: Close any test issues that were created
    if ($script:CreatedIssues.Count -gt 0) {
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
}
