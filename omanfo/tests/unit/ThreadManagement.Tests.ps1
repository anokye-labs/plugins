# ThreadManagement.Tests.ps1
# Pester tests for PR review thread management scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../.github/skills/okyerema/scripts"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Get-UnresolvedThreads" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-UnresolvedThreads.ps1"
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

    It "Should filter to unresolved threads only" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        $result | Should -BeOfType [array]
        # All returned threads should be unresolved
        $result | ForEach-Object { $_.isResolved | Should -Be $false }
    }

    It "Should exclude outdated threads by default" {
        Mock gh { return $fixtureData } -ParameterFilter { $args[0] -eq 'api' }
        
        $result = & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42
        
        # Should not include outdated threads unless explicitly requested
        $result | Where-Object { $_.isOutdated -eq $true } | Should -BeNullOrEmpty
    }
}

Describe "Reply-ReviewThread" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Reply-ReviewThread.ps1"
        $mockResponse = '{"data":{"addPullRequestReviewComment":{"comment":{"id":"PRRC_123"}}}}'
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

    It "Should have required CommentId parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "CommentId"
        $cmd.Parameters['CommentId'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have required Body parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Body"
        $cmd.Parameters['Body'].Attributes.Mandatory | Should -Be $true
    }

    It "Should add reply comment via GraphQL mutation" {
        Mock gh { return $mockResponse } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 42 -CommentId "PRRC_123" -Body "Reply text" *>&1
        
        Should -Invoke gh -Times 1
    }
}

Describe "Resolve-ReviewThreads" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Resolve-ReviewThreads.ps1"
        $mockResponse = '{"data":{"resolveReviewThread":{"thread":{"id":"PRRT_123","isResolved":true}}}}'
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

    It "Should have required ThreadIds parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "ThreadIds"
        $cmd.Parameters['ThreadIds'].Attributes.Mandatory | Should -Be $true
    }

    It "Should accept array of thread IDs" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters['ThreadIds'].ParameterType.Name | Should -Match "String\[\]"
    }

    It "Should resolve single thread" {
        Mock gh { return $mockResponse } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -ThreadIds @("PRRT_123") *>&1
        
        Should -Invoke gh -Times 1
    }

    It "Should resolve multiple threads" {
        Mock gh { return $mockResponse } -ParameterFilter { $args[0] -eq 'api' }
        
        & $scriptPath -Owner "test-org" -Repo "test-repo" -ThreadIds @("PRRT_123", "PRRT_456", "PRRT_789") *>&1
        
        Should -Invoke gh -Times 3
    }
}
