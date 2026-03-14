# PlanMaterialization.Unit.Tests.ps1
# Pester 5 tests for okyerema plan materialization dispatch scripts

BeforeAll {
    $dispatchPath = Join-Path $PSScriptRoot "../../../okyerema/scripts/dispatch"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Invoke-PlanMaterialization" {
    BeforeAll {
        $scriptPath = Join-Path $dispatchPath "Invoke-PlanMaterialization.ps1"
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

    It "Should have required PlanFile parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "PlanFile"
        $cmd.Parameters['PlanFile'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have optional DryRun parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "DryRun"
    }
}

Describe "Sync-PlanToIssues" {
    BeforeAll {
        $scriptPath = Join-Path $dispatchPath "Sync-PlanToIssues.ps1"
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

    It "Should have required PlanFile parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "PlanFile"
        $cmd.Parameters['PlanFile'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have DryRun switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "DryRun"
    }
}
