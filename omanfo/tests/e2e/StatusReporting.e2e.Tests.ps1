#!/usr/bin/env pwsh
<#
.SYNOPSIS
    E2E tests for status reporting slash commands via Copilot CLI.

.DESCRIPTION
    Tests /sitrep, /health, /prcheck, /whatsleft, and work selection commands
    through copilot prompts and verifies outputs.

.NOTES
    Dependencies: copilot CLI on PATH, gh authenticated
    Environment: $env:E2E_TEST_REPO or defaults to anokye-labs/plugins
#>

[CmdletBinding()]
param()

BeforeAll {
    # Configuration
    $script:TestRepo = $env:E2E_TEST_REPO ?? "anokye-labs/plugins"
    $script:RunId = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:CreatedIssues = @()
    $script:TestPRNumber = $null
    
    # Verify prerequisites
    $copilotCmd = Get-Command copilot -ErrorAction SilentlyContinue
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    
    if (-not $copilotCmd) {
        throw "Copilot CLI not found on PATH"
    }
    
    if (-not $ghCmd) {
        throw "GitHub CLI (gh) not found on PATH"
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
    
    Write-Host "🧪 E2E Status Reporting Test Configuration:" -ForegroundColor Cyan
    Write-Host "   Repository: $script:TestRepo" -ForegroundColor Gray
    Write-Host "   Run ID: $script:RunId" -ForegroundColor Gray
    Write-Host ""
    
    # Setup: Create a few test issues for status reporting
    Write-Host "📝 Setting up test issues..." -ForegroundColor Cyan
    
    # Create a Feature with child Tasks
    $setupQuery = @"
mutation CreateTestIssue {
  createIssue(input: {
    repositoryId: \"<repo-id>\"
    title: \"E2E-$script:RunId: Test Feature for Status\"
    body: \"Test feature for status reporting E2E tests\"
  }) {
    issue {
      number
    }
  }
}
"@
    
    # We'll let copilot create them to keep it consistent
    $setupPrompt = @"
Create a Feature issue in $script:TestRepo titled 'E2E-$script:RunId: Status Test Feature' with two Task sub-issues:
- Task 1: Implement feature component
- Task 2: Add tests for feature
"@
    
    $setupOutput = copilot -p $setupPrompt --allow-all-tools -s 2>&1 | Out-String
    $allMatches = [regex]::Matches($setupOutput, '#(\d+)')
    foreach ($match in $allMatches) {
        $script:CreatedIssues += $match.Groups[1].Value
    }
    
    Write-Host "✅ Created $($script:CreatedIssues.Count) test issues" -ForegroundColor Green
}

Describe "Status Reporting E2E Tests" {
    Context "/sitrep Command" {
        It "Should execute /sitrep and return status" {
            $prompt = "/sitrep for $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            # Should contain key status fields
            $output | Should -Match "(Focus|Status|Open|Done|Pending|Blocked)" -Because "Sitrep should include status information"
        }
        
        It "Should handle /sitrep with specific scope" {
            if ($script:CreatedIssues.Count -gt 0) {
                $testIssue = $script:CreatedIssues[0]
                $prompt = "/sitrep for issue #$testIssue in $script:TestRepo"
                
                $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
                
                $output | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "/health Command" {
        It "Should execute /health and return hierarchy health" {
            $prompt = "/health check for $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            # Should contain health metrics
            $output | Should -Match "(health|hierarchy|orphan|type|score)" -Because "Health check should include hierarchy metrics"
        }
        
        It "Should identify test issues in health check" {
            $prompt = "Check hierarchy health for issues containing 'E2E-$script:RunId' in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "/whatsleft Command" {
        It "Should execute /whatsleft and list remaining work" {
            $prompt = "/whatsleft in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            # Should list open issues or indicate completion
            $output | Should -Match "(issue|task|open|remaining|complete|done)" -Because "Whatsleft should show remaining work"
        }
    }
    
    Context "Work Selection" {
        It "Should identify ready issues" {
            $prompt = "What issues are ready to work on in $script:TestRepo?"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            # Should identify ready or blocked issues
            $output | Should -Match "(ready|blocked|available|waiting)" -Because "Should analyze issue readiness"
        }
        
        It "Should identify blocked issues" {
            $prompt = "Show me blocked issues in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should suggest next work item" {
            $prompt = "What should I work on next in $script:TestRepo?"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            # Should provide recommendation
            $output | Should -Match "(suggest|recommend|work on|issue|task)" -Because "Should recommend next work"
        }
    }
    
    Context "Status Queries" {
        It "Should query stalled work" {
            $prompt = "Show me stalled work in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should query orphaned issues" {
            $prompt = "Find orphaned issues in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should check DAG status" {
            $prompt = "Check DAG status for $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
            # Should mention cycles or health
            $output | Should -Match "(dag|cycle|dependency|graph|health)" -Because "DAG check should analyze dependency graph"
        }
    }
    
    Context "PR Status Commands" {
        It "Should handle /prcheck without active PR" {
            $prompt = "/prcheck for the current branch in $script:TestRepo"
            
            # This might fail gracefully or indicate no PR
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should query PR status if PR exists" {
            # Find any open PR to test with
            $prs = gh pr list --repo $script:TestRepo --limit 1 --json number 2>&1 | ConvertFrom-Json
            
            if ($prs.Count -gt 0) {
                $prNum = $prs[0].number
                $prompt = "/prcheck for PR #$prNum in $script:TestRepo"
                
                $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
                
                $output | Should -Not -BeNullOrEmpty
                $output | Should -Match "(status|check|review|thread|approval)" -Because "PR check should show PR status"
            }
        }
    }
    
    Context "Context and Recap Commands" {
        It "Should handle /context request" {
            if ($script:CreatedIssues.Count -gt 0) {
                $testIssue = $script:CreatedIssues[0]
                $prompt = "/context for issue #$testIssue in $script:TestRepo"
                
                $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
                
                $output | Should -Not -BeNullOrEmpty
                # Should provide context about the issue
                $output | Should -Match "(issue|context|about|detail)" -Because "Context should provide issue details"
            }
        }
        
        It "Should handle /recap request" {
            $prompt = "/recap recent activity in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $output | Should -Not -BeNullOrEmpty
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
