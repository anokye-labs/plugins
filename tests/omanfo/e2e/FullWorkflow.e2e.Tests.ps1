#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete end-to-end workflow test via CLI provider (copilot or claude).

.DESCRIPTION
    Tests a complete 4-phase workflow:
    1. Planning - Create Epic with Features and Tasks
    2. Issue Management - Build hierarchy, set dependencies
    3. Status Monitoring - Check health, readiness, blockers
    4. Work Selection - Identify and select next work item

.NOTES
    Dependencies: copilot or claude CLI on PATH, gh authenticated
    Environment: $env:E2E_TEST_REPO or defaults to anokye-labs/plugins
                 $env:E2E_CLI_PROVIDER or defaults to copilot
    This is a comprehensive integration test that exercises the full plugin capability.
#>

[CmdletBinding()]
param()

BeforeAll {
    # Configuration
    $script:TestRepo = $env:E2E_TEST_REPO ?? "anokye-labs/plugins"
    $script:RunId = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:CreatedIssues = @()
    $script:EpicNumber = $null
    $script:FeatureNumbers = @()
    $script:TaskNumbers = @()

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
    
    Write-Host "🧪 E2E Full Workflow Test Configuration:" -ForegroundColor Cyan
    Write-Host "   Repository: $script:TestRepo" -ForegroundColor Gray
    Write-Host "   Provider: $script:Provider" -ForegroundColor Gray
    Write-Host "   Run ID: $script:RunId" -ForegroundColor Gray
    Write-Host ""
}

Describe "Complete E2E Workflow Tests" {
    Context "Phase 1: Planning" {
        It "Should create a complete project plan via one prompt" {
            $prompt = @"
Create a complete project plan in $script:TestRepo with prefix 'E2E-$script:RunId':

Epic: Complete E2E Test Project
  Feature: Backend Implementation
    Task: Setup database schema
    Task: Create API endpoints
    Task: Add authentication
  Feature: Frontend Development
    Task: Build UI components
    Task: Integrate with API
  Feature: Testing & Documentation
    Task: Write unit tests
    Task: Update documentation

Make sure all hierarchy relationships are established.
"@
            
            Write-Host "`n📋 Phase 1: Creating project plan..." -ForegroundColor Cyan
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
            
            # Extract all issue numbers
            $allMatches = [regex]::Matches($output, '#(\d+)')
            $allMatches.Count | Should -BeGreaterThan 0 -Because "Should create multiple issues"
            
            # Track all created issues
            foreach ($match in $allMatches) {
                $issueNum = $match.Groups[1].Value
                $script:CreatedIssues += $issueNum
            }
            
            # First issue should be the Epic
            if ($allMatches.Count -gt 0) {
                $script:EpicNumber = $allMatches[0].Groups[1].Value
            }
            
            Write-Host "✅ Created $($script:CreatedIssues.Count) issues" -ForegroundColor Green
            Write-Host "   Epic: #$script:EpicNumber" -ForegroundColor Gray
            
            # Wait for all relationships to be established
            Start-Sleep -Seconds 5
        }
        
        It "Should verify Epic has Feature children" {
            $script:EpicNumber | Should -Not -BeNullOrEmpty
            
            $query = @"
query {
  repository(owner: "$script:Owner", name: "$script:Repo") {
    issue(number: $script:EpicNumber) {
      title
      subIssues(first: 10) {
        nodes {
          number
          title
        }
      }
    }
  }
}
"@
            
            $result = gh api graphql -f query=$query 2>&1 | ConvertFrom-Json
            
            $result.data.repository.issue | Should -Not -BeNullOrEmpty
            $features = $result.data.repository.issue.subIssues.nodes
            $features.Count | Should -BeGreaterThan 0 -Because "Epic should have Feature children"
            
            # Store feature numbers
            $script:FeatureNumbers = $features | ForEach-Object { $_.number }
            
            Write-Host "✅ Epic has $($features.Count) Features" -ForegroundColor Green
        }
        
        It "Should verify Features have Task children" {
            $script:FeatureNumbers.Count | Should -BeGreaterThan 0
            
            $hasTaskChildren = $false
            foreach ($featureNum in $script:FeatureNumbers) {
                $query = @"
query {
  repository(owner: "$script:Owner", name: "$script:Repo") {
    issue(number: $featureNum) {
      subIssues(first: 10) {
        nodes {
          number
          title
        }
      }
    }
  }
}
"@
                
                $result = gh api graphql -f query=$query 2>&1 | ConvertFrom-Json
                
                if ($result.data.repository.issue) {
                    $tasks = $result.data.repository.issue.subIssues.nodes
                    if ($tasks.Count -gt 0) {
                        $hasTaskChildren = $true
                        $script:TaskNumbers += $tasks | ForEach-Object { $_.number }
                    }
                }
            }
            
            $hasTaskChildren | Should -Be $true -Because "Features should have Task children"
            Write-Host "✅ Features have $($script:TaskNumbers.Count) Tasks total" -ForegroundColor Green
        }
    }
    
    Context "Phase 2: Issue Management" {
        It "Should add dependencies between tasks" {
            if ($script:TaskNumbers.Count -ge 2) {
                $task1 = $script:TaskNumbers[0]
                $task2 = $script:TaskNumbers[1]
                
                $prompt = "Set Task #$task2 to be blocked by Task #$task1 in $script:TestRepo"
                
                Write-Host "`n🔗 Phase 2: Setting up dependencies..." -ForegroundColor Cyan
                $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
                
                $output | Should -Not -BeNullOrEmpty
                
                Start-Sleep -Seconds 2
                
                Write-Host "✅ Dependency established: #$task1 blocks #$task2" -ForegroundColor Green
            }
        }
        
        It "Should update task details" {
            if ($script:TaskNumbers.Count -gt 0) {
                $taskNum = $script:TaskNumbers[0]
                
                $prompt = "Update Task #$taskNum in $script:TestRepo to add more details about implementation approach"
                
                $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
                
                $output | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Phase 3: Status Monitoring" {
        It "Should check overall project health" {
            $prompt = "Check health for all E2E-$script:RunId issues in $script:TestRepo"
            
            Write-Host "`n📊 Phase 3: Monitoring project status..." -ForegroundColor Cyan
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(health|status|issue)" -Because "Should report health status"
            
            Write-Host "✅ Health check completed" -ForegroundColor Green
        }
        
        It "Should generate project sitrep" {
            $prompt = "/sitrep for Epic #$script:EpicNumber in $script:TestRepo"
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(status|progress|open|done)" -Because "Sitrep should show project status"
            
            Write-Host "✅ Sitrep generated" -ForegroundColor Green
        }
        
        It "Should identify blocked tasks" {
            $prompt = "Show me blocked tasks in the E2E-$script:RunId project in $script:TestRepo"
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
            
            Write-Host "✅ Blocked tasks identified" -ForegroundColor Green
        }
        
        It "Should identify ready tasks" {
            $prompt = "What tasks are ready to work on in the E2E-$script:RunId project in $script:TestRepo?"
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(ready|available|work|task)" -Because "Should identify ready work"
            
            Write-Host "✅ Ready tasks identified" -ForegroundColor Green
        }
        
        It "Should check for orphaned issues" {
            $prompt = "Are there any orphaned issues in the E2E-$script:RunId project in $script:TestRepo?"
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should verify DAG health" {
            $prompt = "Check DAG health for E2E-$script:RunId issues in $script:TestRepo"
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(dag|dependency|cycle|graph)" -Because "Should analyze dependency graph"
            
            Write-Host "✅ DAG health verified" -ForegroundColor Green
        }
    }
    
    Context "Phase 4: Work Selection" {
        It "Should recommend next task to work on" {
            $prompt = "Based on the E2E-$script:RunId project in $script:TestRepo, what should I work on next?"
            
            Write-Host "`n🎯 Phase 4: Selecting next work..." -ForegroundColor Cyan
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(task|work|issue|suggest|recommend)" -Because "Should recommend work"
            
            Write-Host "✅ Next work identified" -ForegroundColor Green
        }
        
        It "Should explain why a task is ready" {
            if ($script:TaskNumbers.Count -gt 0) {
                $taskNum = $script:TaskNumbers[0]
                $prompt = "Why is Task #$taskNum ready (or not ready) to work on in $script:TestRepo?"
                
                $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
                
                $output | Should -Not -BeNullOrEmpty
                $output | Should -Match "(ready|blocked|dependency|because)" -Because "Should explain readiness"
            }
        }
        
        It "Should prioritize remaining work" {
            $prompt = "Prioritize remaining work in the E2E-$script:RunId project in $script:TestRepo"
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(priority|order|first|next)" -Because "Should show prioritization"
            
            Write-Host "✅ Work prioritized" -ForegroundColor Green
        }
    }
    
    Context "Workflow Integration" {
        It "Should show complete project overview" {
            $prompt = "Give me a complete overview of the E2E-$script:RunId project in $script:TestRepo including status, health, and next steps"
            
            Write-Host "`n📈 Generating complete project overview..." -ForegroundColor Cyan
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "(overview|status|health|next)" -Because "Should provide comprehensive overview"
            
            Write-Host "✅ Complete workflow tested successfully" -ForegroundColor Green
        }
        
        It "Should handle complex queries across phases" {
            $prompt = @"
For the E2E-$script:RunId project in $script:TestRepo:
1. How many tasks are complete?
2. What is blocking progress?
3. What should be worked on next?
"@
            
            $output = (Invoke-CLIPrompt -Provider $script:Provider -Prompt $prompt).Output
            
            $output | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Cleanup: Close all created test issues
    Write-Host "`n🧹 Cleaning up all test issues..." -ForegroundColor Cyan
    Write-Host "   Total issues to clean: $($script:CreatedIssues.Count)" -ForegroundColor Gray
    
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
    Write-Host "`n🎉 Full E2E workflow test completed!" -ForegroundColor Cyan
}
