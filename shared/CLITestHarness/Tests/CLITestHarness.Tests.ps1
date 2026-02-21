#!/usr/bin/env pwsh
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'CLITestHarness.psm1'
    Import-Module $modulePath -Force
}

Describe "CLITestHarness Module" {
    Context "Get-SupportedProviders" {
        It "Should return copilot and claude" {
            $providers = Get-SupportedProviders
            $providers | Should -Contain 'copilot'
            $providers | Should -Contain 'claude'
        }

        It "Should return exactly 2 providers" {
            $providers = Get-SupportedProviders
            $providers.Count | Should -Be 2
        }
    }

    Context "Test-ProviderAvailable" {
        It "Should accept valid provider names" {
            { Test-ProviderAvailable -Provider copilot -SkipAuthCheck } | Should -Not -Throw
            { Test-ProviderAvailable -Provider claude -SkipAuthCheck } | Should -Not -Throw
        }

        It "Should return an object with Available property" {
            $result = Test-ProviderAvailable -Provider copilot -SkipAuthCheck
            $result.PSObject.Properties.Name | Should -Contain 'Available'
            $result.PSObject.Properties.Name | Should -Contain 'Provider'
            $result.PSObject.Properties.Name | Should -Contain 'Reason'
            $result.PSObject.Properties.Name | Should -Contain 'InstallUrl'
        }

        It "Should report correct provider name" {
            $result = Test-ProviderAvailable -Provider copilot -SkipAuthCheck
            $result.Provider | Should -Be 'copilot'

            $result2 = Test-ProviderAvailable -Provider claude -SkipAuthCheck
            $result2.Provider | Should -Be 'claude'
        }
    }

    Context "Get-IssueNumbersFromOutput" {
        It "Should extract single issue number" {
            $nums = Get-IssueNumbersFromOutput -Text "Created issue #42 successfully"
            $nums | Should -Contain 42
        }

        It "Should extract multiple issue numbers" {
            $nums = Get-IssueNumbersFromOutput -Text "Created #10, #20, and #30"
            $nums.Count | Should -Be 3
            $nums | Should -Contain 10
            $nums | Should -Contain 20
            $nums | Should -Contain 30
        }

        It "Should return empty array when no issues found" {
            $nums = Get-IssueNumbersFromOutput -Text "No issues here"
            $nums.Count | Should -Be 0
        }

        It "Should not match bare numbers without # prefix" {
            $nums = Get-IssueNumbersFromOutput -Text "https://github.com/org/repo/issues/99"
            $nums.Count | Should -Be 0
        }

        It "Should match issue references with # in URLs" {
            $nums = Get-IssueNumbersFromOutput -Text "See https://github.com/org/repo/issues/99 (issue #99)"
            $nums | Should -Contain 99
        }
    }

    Context "Invoke-CLIPrompt parameter validation" {
        It "Should reject invalid provider" {
            { Invoke-CLIPrompt -Provider 'invalid' -Prompt 'test' } | Should -Throw
        }
    }

    Context "Close-TestIssues parameter validation" {
        It "Should have mandatory Owner parameter" {
            $cmd = Get-Command Close-TestIssues
            $param = $cmd.Parameters['Owner']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It "Should have mandatory Repo parameter" {
            $cmd = Get-Command Close-TestIssues
            $param = $cmd.Parameters['Repo']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It "Should have mandatory IssueNumbers parameter" {
            $cmd = Get-Command Close-TestIssues
            $param = $cmd.Parameters['IssueNumbers']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }
    }
}

AfterAll {
    Remove-Module CLITestHarness -Force -ErrorAction SilentlyContinue
}
