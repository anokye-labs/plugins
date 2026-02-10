# PRIntelligence.Tests.ps1
# Pester tests for PR intelligence and analysis scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../.github/skills/okyerema/scripts"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Get-PRStatus" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-PRStatus.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "pr-status.json") -Raw
    }

    It "Should have required parameters" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters.Keys | Should -Contain "PullNumber"
    }

    It "Should query PR data via GraphQL" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42 *>&1
        
        Should -Invoke gh -Times 1
    }

    It "Should return PSCustomObject" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result | Should -BeOfType [PSCustomObject]
    }

    It "Should include PR number in output" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result.Number | Should -Be 42
    }

    It "Should include state in output" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result.PSObject.Properties.Name | Should -Contain "State"
    }

    It "Should include mergeable status" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result.PSObject.Properties.Name | Should -Contain "Mergeable"
    }
}

Describe "Get-PRHealth" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-PRHealth.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "pr-review-threads.json") -Raw
    }

    It "Should have required Owner parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters['Owner'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required Repo parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters['Repo'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required PullNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "PullNumber"
        $cmd.Parameters['PullNumber'].Attributes.Mandatory | Should -Be $true
    }

    It "Should query PR review threads" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42 *>&1
        
        Should -Invoke gh -Times 1
    }

    It "Should return flattened health metrics" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result | Should -BeOfType [PSCustomObject]
    }

    It "Should include TotalThreads in output" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result.PSObject.Properties.Name | Should -Contain "TotalThreads"
    }

    It "Should include ResolvedThreads count" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result.PSObject.Properties.Name | Should -Contain "ResolvedThreads"
    }

    It "Should include UnresolvedThreads count" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result.PSObject.Properties.Name | Should -Contain "UnresolvedThreads"
    }

    It "Should categorize automated vs human threads" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result.PSObject.Properties.Name | Should -Contain "AutomatedThreads"
        $result.PSObject.Properties.Name | Should -Contain "HumanThreads"
    }
}

Describe "Get-ThreadSeverity" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-ThreadSeverity.ps1"
        $fixtureData = Get-Content (Join-Path $fixturesPath "pr-review-threads.json") -Raw
    }

    It "Should have required Owner parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters['Owner'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required Repo parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters['Repo'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required PullNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "PullNumber"
        $cmd.Parameters['PullNumber'].Attributes.Mandatory | Should -Be $true
    }

    It "Should query PR threads with comments" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42 *>&1
        
        Should -Invoke gh -Times 1
    }

    It "Should analyze thread content for severity" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result | Should -Not -BeNullOrEmpty
    }

    It "Should return array of threads with severity" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result | Should -BeOfType [array]
    }
}

Describe "Find-IssueByPR" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Find-IssueByPR.ps1"
        $mockResponse = @'
{
  "data": {
    "repository": {
      "pullRequest": {
        "closingIssuesReferences": {
          "nodes": [
            { "number": 10, "title": "Implement feature" }
          ]
        }
      }
    }
  }
}
'@
    }

    It "Should have required Owner parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters['Owner'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required Repo parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters['Repo'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required PullNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "PullNumber"
        $cmd.Parameters['PullNumber'].Attributes.Mandatory | Should -Be $true
    }

    It "Should query closing issues for PR" {
        Mock gh { return $mockResponse } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42 *>&1
        
        Should -Invoke gh -Times 1
    }

    It "Should return linked issues" {
        Mock gh { return $mockResponse } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-PRTimeline" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-PRTimeline.ps1"
        $mockResponse = @'
{
  "data": {
    "repository": {
      "pullRequest": {
        "timelineItems": {
          "nodes": [
            { "__typename": "IssueComment", "createdAt": "2026-01-01T10:00:00Z" }
          ]
        }
      }
    }
  }
}
'@
    }

    It "Should have required Owner parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters['Owner'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required Repo parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters['Repo'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required PullNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "PullNumber"
        $cmd.Parameters['PullNumber'].Attributes.Mandatory | Should -Be $true
    }

    It "Should query PR timeline events" {
        Mock gh { return $mockResponse } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42 *>&1
        
        Should -Invoke gh -Times 1
    }

    It "Should return chronological timeline" {
        Mock gh { return $mockResponse } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe "Submit-PRReview" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Submit-PRReview.ps1"
        $mockResponse = '{"data":{"addPullRequestReview":{"pullRequestReview":{"id":"PRR_123"}}}}'
    }

    It "Should have required Owner parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters['Owner'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required Repo parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters['Repo'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required PullNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "PullNumber"
        $cmd.Parameters['PullNumber'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have Event parameter with valid values" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Event"
    }

    It "Should accept Body parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Body"
    }

    It "Should submit review via GraphQL mutation" {
        Mock gh { return $mockResponse } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42 -Event "APPROVE" -Body "LGTM" *>&1
        
        Should -Invoke gh -Times 1
    }
}
