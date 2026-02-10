# PlanMaterialization.Tests.ps1
# Pester tests for plan materialization scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../.github/skills/okyerema/scripts"
    $fixturesPath = Join-Path $PSScriptRoot "../fixtures"
}

Describe "Invoke-PlanMaterialization" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Invoke-PlanMaterialization.ps1"
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

    It "Should validate PlanFile parameter with script" {
        $cmd = Get-Command $scriptPath
        $validateScript = $cmd.Parameters['PlanFile'].Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateScriptAttribute' }
        $validateScript | Should -Not -BeNullOrEmpty
    }

    It "Should have optional DryRun parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "DryRun"
    }
}

Describe "Sync-PlanToIssues" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Sync-PlanToIssues.ps1"
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

    It "Should validate PlanFile parameter with script" {
        $cmd = Get-Command $scriptPath
        $validateScript = $cmd.Parameters['PlanFile'].Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateScriptAttribute' }
        $validateScript | Should -Not -BeNullOrEmpty
    }

    It "Should have DryRun switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "DryRun"
    }
}
