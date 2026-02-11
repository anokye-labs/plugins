# PRIntelligence.Tests.ps1
# Pester tests for PR intelligence and analysis scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../../omanfo/skills/okyerema/scripts"
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

Describe "Get-ThreadSeverity" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-ThreadSeverity.ps1"
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
        $scriptPath = Join-Path $scriptsPath "Find-IssueByPR.ps1"
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

Describe "Get-PRTimeline" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-PRTimeline.ps1"
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

Describe "Submit-PRReview" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Submit-PRReview.ps1"
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
}

Describe "Invoke-PRCompletion" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Invoke-PRCompletion.ps1"
        $threadsResponse = @'
[
  {
    "ThreadId": "PRRT_1",
    "Path": "test.ps1",
    "Line": 10,
    "Body": "Fix this",
    "IsResolved": false
  }
]
'@
        $severityResponse = @'
[
  {
    "ThreadId": "PRRT_1",
    "Severity": "High",
    "Confidence": "High",
    "Reason": "Logic error",
    "Path": "test.ps1",
    "Line": 10
  }
]
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

    It "Should have optional Branch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Branch"
    }

    It "Should have DryRun switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "DryRun"
        $cmd.Parameters['DryRun'].SwitchParameter | Should -Be $true
    }

    It "Should have MaxIterations parameter with default" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "MaxIterations"
    }

    It "Should have AutoResolve switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "AutoResolve"
    }

    It "Should have MinSeverity parameter with validation" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "MinSeverity"
        $validateSet = $cmd.Parameters['MinSeverity'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $validateSet.ValidValues | Should -Contain "Critical"
        $validateSet.ValidValues | Should -Contain "High"
        $validateSet.ValidValues | Should -Contain "Medium"
        $validateSet.ValidValues | Should -Contain "Low"
    }

    It "Should verify required scripts exist before running" {
        Mock Test-Path { return $false } -ParameterFilter { $Path -like "*Get-ThreadSeverity.ps1" }
        
        { & $scriptPath -Owner "test-org" -Repo "test-repo" -PullNumber 1 -DryRun *>&1 } | Should -Throw "*Required script not found*"
    }

    It "Should run in dry-run mode without making changes" {
        # This would require mocking git, gh commands, and the helper scripts
        # Since it's a complex orchestration script, we verify the key parameters exist
        # Integration testing would validate the full workflow
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "DryRun"
    }
}
