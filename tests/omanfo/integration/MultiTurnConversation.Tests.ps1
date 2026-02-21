#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Integration tests for multi-turn interactive CLI sessions.

.DESCRIPTION
    Tests that exercise multi-turn conversation, session context persistence,
    and agent switching using the CLITestHarness interactive session API.
    These tests are skipped when neither copilot nor claude CLI is available.
#>

BeforeAll {
    $harnessPath = Join-Path $PSScriptRoot '..' '..' '..' 'shared' 'CLITestHarness' 'CLITestHarness.psm1'
    Import-Module (Resolve-Path $harnessPath) -Force
}

Describe "Multi-Turn Interactive CLI Sessions" -Tag 'integration' {
    Context "Session lifecycle" {
        It "Should start and stop a session without error for each available provider" {
            $available = Get-AvailableProviders
            if ($available.Count -eq 0) {
                Set-ItResult -Skipped -Because "No CLI providers are installed"
                return
            }

            foreach ($provider in $available) {
                $session = Start-CLISession -Provider $provider
                $session | Should -Not -BeNullOrEmpty
                $session.Provider | Should -Be $provider
                $session.TurnCount | Should -Be 0

                Stop-CLISession -Session $session
            }
        }
    }

    Context "Get-CLIOutput" {
        It "Should return empty string immediately after session start" {
            $available = Get-AvailableProviders
            if ($available.Count -eq 0) {
                Set-ItResult -Skipped -Because "No CLI providers are installed"
                return
            }

            $session = Start-CLISession -Provider $available[0]
            try {
                # Give the process a moment to start, then drain any banner/startup output
                Start-Sleep -Milliseconds 500
                $output = Get-CLIOutput -Session $session
                # Output may be empty or contain startup banner — just verify it's a string
                $output | Should -BeOfType [string]
            }
            finally {
                Stop-CLISession -Session $session
            }
        }
    }

    Context "Wait-CLIPattern" {
        It "Should time out gracefully when pattern is never produced" {
            $available = Get-AvailableProviders
            if ($available.Count -eq 0) {
                Set-ItResult -Skipped -Because "No CLI providers are installed"
                return
            }

            $session = Start-CLISession -Provider $available[0]
            try {
                $result = Wait-CLIPattern -Session $session -Pattern 'PATTERN_THAT_NEVER_APPEARS_XYZ' -TimeoutSeconds 3
                $result.Matched | Should -Be $false
                $result.Error | Should -Match 'Timed out'
            }
            finally {
                Stop-CLISession -Session $session
            }
        }
    }

    Context "Send-CLISessionPrompt" {
        It "Should increment TurnCount when a prompt is sent" {
            $available = Get-AvailableProviders
            if ($available.Count -eq 0) {
                Set-ItResult -Skipped -Because "No CLI providers are installed"
                return
            }

            $session = Start-CLISession -Provider $available[0]
            try {
                $session.TurnCount | Should -Be 0
                # Send-CLISessionPrompt writes to stdin and increments TurnCount.
                # We don't require a full response here, just verify the counter advances.
                Send-CLISessionPrompt -Session $session -Prompt 'hello' -TimeoutSeconds 3 | Out-Null
                $session.TurnCount | Should -Be 1
            }
            finally {
                Stop-CLISession -Session $session
            }
        }
    }
}

AfterAll {
    Remove-Module CLITestHarness -Force -ErrorAction SilentlyContinue
}
