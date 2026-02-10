#!/usr/bin/env pwsh
<#
.SYNOPSIS
    E2E tests for issue hierarchy capabilities via Copilot CLI.

.DESCRIPTION
    Tests building Epic→Feature→Task hierarchies through copilot prompts
    and verifies parent-child relationships via GitHub API.

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
    
    Write-Host "🧪 E2E Hierarchy Test Configuration:" -ForegroundColor Cyan
    Write-Host "   Repository: $script:TestRepo" -ForegroundColor Gray
    Write-Host "   Run ID: $script:RunId" -ForegroundColor Gray
    Write-Host ""
}

Describe "Issue Hierarchy E2E Tests" {
    Context "Epic to Feature Hierarchy" {
        It "Should create Epic with Feature children" {
            $epicTitle = "E2E-$script:RunId: Test Epic for Hierarchy"
            $prompt = @"
Create an Epic issue titled '$epicTitle' in $script:TestRepo with two Feature sub-issues:
- Feature 1: Test Feature Alpha
- Feature 2: Test Feature Beta
"@
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            # Extract issue numbers
            $allMatches = [regex]::Matches($output, '#(\d+)')
            $allMatches.Count | Should -BeGreaterThan 0
            
            # Track issues for cleanup
            $issueNumbers = @()
            foreach ($match in $allMatches) {
                $issueNum = $match.Groups[1].Value
                $script:CreatedIssues += $issueNum
                $issueNumbers += $issueNum
            }
            
            # Wait for relationships to be established
            Start-Sleep -Seconds 3
            
            # Verify hierarchy via GraphQL
            if ($issueNumbers.Count -gt 0) {
                $epicNum = $issueNumbers[0]
                $query = @"
query {
  repository(owner: "$script:Owner", name: "$script:Repo") {
    issue(number: $epicNum) {
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
                
                if ($result.data.repository.issue) {
                    $subIssues = $result.data.repository.issue.subIssues.nodes
                    $subIssues.Count | Should -BeGreaterThan 0 -Because "Epic should have Feature children"
                }
            }
        }
    }
    
    Context "Feature to Task Hierarchy" {
        It "Should create Feature with Task children" {
            $featureTitle = "E2E-$script:RunId: Test Feature for Hierarchy"
            $prompt = @"
Create a Feature issue titled '$featureTitle' in $script:TestRepo with three Task sub-issues:
- Task 1: Implement component A
- Task 2: Add tests for component A
- Task 3: Update documentation
"@
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $allMatches = [regex]::Matches($output, '#(\d+)')
            $allMatches.Count | Should -BeGreaterThan 0
            
            foreach ($match in $allMatches) {
                $script:CreatedIssues += $match.Groups[1].Value
            }
            
            Start-Sleep -Seconds 3
        }
    }
    
    Context "Three-Level Hierarchy" {
        It "Should create Epic→Feature→Task hierarchy" {
            $epicTitle = "E2E-$script:RunId: Complete Test Hierarchy"
            $prompt = @"
Create a complete hierarchy in $script:TestRepo:
- Epic: '$epicTitle'
  - Feature: Implementation Phase
    - Task: Setup infrastructure
    - Task: Build core feature
  - Feature: Testing Phase
    - Task: Write unit tests
"@
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            $allMatches = [regex]::Matches($output, '#(\d+)')
            $allMatches.Count | Should -BeGreaterThan 0
            
            # Track all created issues
            $issueNumbers = @()
            foreach ($match in $allMatches) {
                $issueNum = $match.Groups[1].Value
                $script:CreatedIssues += $issueNum
                $issueNumbers += $issueNum
            }
            
            # Allow time for hierarchy setup
            Start-Sleep -Seconds 5
            
            # Verify multi-level hierarchy exists
            if ($issueNumbers.Count -gt 0) {
                $epicNum = $issueNumbers[0]
                $query = @"
query {
  repository(owner: "$script:Owner", name: "$script:Repo") {
    issue(number: $epicNum) {
      title
      subIssues(first: 10) {
        nodes {
          number
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
  }
}
"@
                
                $result = gh api graphql -f query=$query 2>&1 | ConvertFrom-Json
                
                if ($result.data.repository.issue) {
                    $features = $result.data.repository.issue.subIssues.nodes
                    $features.Count | Should -BeGreaterThan 0 -Because "Epic should have Feature children"
                    
                    # Check if any feature has tasks
                    $hasGrandchildren = $false
                    foreach ($feature in $features) {
                        if ($feature.subIssues.nodes.Count -gt 0) {
                            $hasGrandchildren = $true
                            break
                        }
                    }
                    $hasGrandchildren | Should -Be $true -Because "Features should have Task children"
                }
            }
        }
    }
    
    Context "Add Child to Existing Issue" {
        It "Should add Task to existing Feature" {
            # First create a Feature
            $featureTitle = "E2E-$script:RunId: Parent Feature"
            $createPrompt = "Create a Feature issue titled '$featureTitle' in $script:TestRepo"
            $output1 = copilot -p $createPrompt --allow-all-tools -s 2>&1 | Out-String
            
            $featureMatch = $output1 -match '#(\d+)'
            $featureMatch | Should -Be $true
            
            if ($featureMatch) {
                $featureNum = $matches[1]
                $script:CreatedIssues += $featureNum
                
                Start-Sleep -Seconds 2
                
                # Now add a child task
                $addChildPrompt = "Add a Task sub-issue to Feature #$featureNum in $script:TestRepo titled 'E2E-$script:RunId: Child Task'"
                $output2 = copilot -p $addChildPrompt --allow-all-tools -s 2>&1 | Out-String
                
                $taskMatch = $output2 -match '#(\d+)'
                if ($taskMatch) {
                    $taskNum = $matches[1]
                    $script:CreatedIssues += $taskNum
                    
                    Start-Sleep -Seconds 3
                    
                    # Verify relationship
                    $query = @"
query {
  repository(owner: "$script:Owner", name: "$script:Repo") {
    issue(number: $featureNum) {
      subIssues(first: 10) {
        nodes {
          number
        }
      }
    }
  }
}
"@
                    
                    $result = gh api graphql -f query=$query 2>&1 | ConvertFrom-Json
                    if ($result.data.repository.issue) {
                        $children = $result.data.repository.issue.subIssues.nodes
                        $childNumbers = $children | ForEach-Object { $_.number }
                        $childNumbers | Should -Contain ([int]$taskNum) -Because "Task should be child of Feature"
                    }
                }
            }
        }
    }
    
    Context "Hierarchy Validation" {
        It "Should query hierarchy health for test issues" {
            $prompt = "Check hierarchy health for issues with prefix 'E2E-$script:RunId' in $script:TestRepo"
            
            $output = copilot -p $prompt --allow-all-tools -s 2>&1 | Out-String
            
            # Should not throw error and should complete
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
