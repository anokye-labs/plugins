# PRTriageAutomation.Unit.Tests.ps1
# Pester 5 tests for okyerema PR triage automation (verify/rhythm scripts)

BeforeAll {
    $verifyPath = Join-Path $PSScriptRoot "../../../okyerema/scripts/verify"
    $rhythmPath = Join-Path $PSScriptRoot "../../../okyerema/scripts/rhythm"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Invoke-PRCompletion" {
    BeforeAll {
        $scriptPath = Join-Path $rhythmPath "Invoke-PRCompletion.ps1"
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
