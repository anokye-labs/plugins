# PRIntelligence.Unit.Tests.ps1
# Pester 5 tests for okyerema PR intelligence verify scripts

BeforeAll {
    $verifyPath = Join-Path $PSScriptRoot "../../../okyerema/scripts/verify"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Get-PRStatus" {
    BeforeAll {
        $scriptPath = Join-Path $verifyPath "Get-PRStatus.ps1"
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
        $scriptPath = Join-Path $verifyPath "Get-PRHealth.ps1"
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

    It "Should have optional Brief switch" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Brief"
        $cmd.Parameters['Brief'].SwitchParameter | Should -Be $true
    }
}

Describe "Get-PRTimeline" {
    BeforeAll {
        $scriptPath = Join-Path $verifyPath "Get-PRTimeline.ps1"
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
}

Describe "Get-ThreadSeverity" {
    BeforeAll {
        $scriptPath = Join-Path $verifyPath "Get-ThreadSeverity.ps1"
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
}

Describe "Find-IssueByPR" {
    BeforeAll {
        $scriptPath = Join-Path $verifyPath "Find-IssueByPR.ps1"
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

    It "Should have required IssueNumber parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "IssueNumber"
        $cmd.Parameters['IssueNumber'].Attributes.Mandatory | Should -Be $true
    }
}
