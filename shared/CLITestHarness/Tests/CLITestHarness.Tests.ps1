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

    Context "Get-CLIOutput" {
        It "Should be exported from the module" {
            $cmd = Get-Command Get-CLIOutput -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty
        }

        It "Should require mandatory Session parameter" {
            $cmd = Get-Command Get-CLIOutput
            $param = $cmd.Parameters['Session']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It "Should drain the output buffer and return joined lines" {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
            $queue.Enqueue('line one')
            $queue.Enqueue('line two')
            $fakeProcess = [PSCustomObject]@{ HasExited = $false }
            $session = [PSCustomObject]@{
                Process      = $fakeProcess
                Provider     = 'copilot'
                OutputBuffer = $queue
                ErrorBuffer  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
                StdoutEvent  = [PSCustomObject]@{ Name = 'fake-stdout'; Id = 0 }
                StderrEvent  = [PSCustomObject]@{ Name = 'fake-stderr'; Id = 0 }
                StartTime    = Get-Date
                TurnCount    = 0
            }

            $output = Get-CLIOutput -Session $session
            $output | Should -Match 'line one'
            $output | Should -Match 'line two'
            $queue.Count | Should -Be 0
        }

        It "Should return empty string when buffer is empty" {
            $fakeProcess = [PSCustomObject]@{ HasExited = $false }
            $session = [PSCustomObject]@{
                Process      = $fakeProcess
                Provider     = 'copilot'
                OutputBuffer = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
                ErrorBuffer  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
                StdoutEvent  = [PSCustomObject]@{ Name = 'fake-stdout'; Id = 0 }
                StderrEvent  = [PSCustomObject]@{ Name = 'fake-stderr'; Id = 0 }
                StartTime    = Get-Date
                TurnCount    = 0
            }

            $output = Get-CLIOutput -Session $session
            $output | Should -Be ''
        }

        It "Should include error buffer when IncludeErrorOutput is set" {
            $outQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
            $outQueue.Enqueue('stdout line')
            $errQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
            $errQueue.Enqueue('stderr line')
            $fakeProcess = [PSCustomObject]@{ HasExited = $false }
            $session = [PSCustomObject]@{
                Process      = $fakeProcess
                Provider     = 'copilot'
                OutputBuffer = $outQueue
                ErrorBuffer  = $errQueue
                StdoutEvent  = [PSCustomObject]@{ Name = 'fake-stdout'; Id = 0 }
                StderrEvent  = [PSCustomObject]@{ Name = 'fake-stderr'; Id = 0 }
                StartTime    = Get-Date
                TurnCount    = 0
            }

            $output = Get-CLIOutput -Session $session -IncludeErrorOutput
            $output | Should -Match 'stdout line'
            $output | Should -Match 'stderr line'
        }
    }

    Context "Wait-CLIPattern" {
        It "Should be exported from the module" {
            $cmd = Get-Command Wait-CLIPattern -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty
        }

        It "Should require mandatory Session parameter" {
            $cmd = Get-Command Wait-CLIPattern
            $param = $cmd.Parameters['Session']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It "Should require mandatory Pattern parameter" {
            $cmd = Get-Command Wait-CLIPattern
            $param = $cmd.Parameters['Pattern']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It "Should return Matched=true when pattern is already in buffer" {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
            $queue.Enqueue('Thinking...')
            $queue.Enqueue('Created issue #42 successfully')
            $fakeProcess = [PSCustomObject]@{ HasExited = $false }
            $session = [PSCustomObject]@{
                Process      = $fakeProcess
                Provider     = 'copilot'
                OutputBuffer = $queue
                ErrorBuffer  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
                StdoutEvent  = [PSCustomObject]@{ Name = 'fake-stdout'; Id = 0 }
                StderrEvent  = [PSCustomObject]@{ Name = 'fake-stderr'; Id = 0 }
                StartTime    = Get-Date
                TurnCount    = 0
            }

            $result = Wait-CLIPattern -Session $session -Pattern '#\d+' -TimeoutSeconds 5
            $result.Matched | Should -Be $true
            $result.Output | Should -Match '#42'
            $result.Error | Should -BeNullOrEmpty
        }

        It "Should return Matched=false and error on timeout" {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
            $queue.Enqueue('some other output')
            $fakeProcess = [PSCustomObject]@{ HasExited = $false }
            $session = [PSCustomObject]@{
                Process      = $fakeProcess
                Provider     = 'copilot'
                OutputBuffer = $queue
                ErrorBuffer  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
                StdoutEvent  = [PSCustomObject]@{ Name = 'fake-stdout'; Id = 0 }
                StderrEvent  = [PSCustomObject]@{ Name = 'fake-stderr'; Id = 0 }
                StartTime    = Get-Date
                TurnCount    = 0
            }

            $result = Wait-CLIPattern -Session $session -Pattern 'NEVER_MATCHES_XYZ' -TimeoutSeconds 1
            $result.Matched | Should -Be $false
            $result.Error | Should -Match 'Timed out'
        }

        It "Should return Matched=false when session process has exited" {
            $fakeProcess = [PSCustomObject]@{ HasExited = $true }
            $session = [PSCustomObject]@{
                Process      = $fakeProcess
                Provider     = 'copilot'
                OutputBuffer = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
                ErrorBuffer  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
                StdoutEvent  = [PSCustomObject]@{ Name = 'fake-stdout'; Id = 0 }
                StderrEvent  = [PSCustomObject]@{ Name = 'fake-stderr'; Id = 0 }
                StartTime    = Get-Date
                TurnCount    = 0
            }

            $result = Wait-CLIPattern -Session $session -Pattern 'anything'
            $result.Matched | Should -Be $false
            $result.Error | Should -Match 'exited'
        }

        It "Should return Match object with capture groups" {
            $queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
            $queue.Enqueue('issue number is #99')
            $fakeProcess = [PSCustomObject]@{ HasExited = $false }
            $session = [PSCustomObject]@{
                Process      = $fakeProcess
                Provider     = 'copilot'
                OutputBuffer = $queue
                ErrorBuffer  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
                StdoutEvent  = [PSCustomObject]@{ Name = 'fake-stdout'; Id = 0 }
                StderrEvent  = [PSCustomObject]@{ Name = 'fake-stderr'; Id = 0 }
                StartTime    = Get-Date
                TurnCount    = 0
            }

            $result = Wait-CLIPattern -Session $session -Pattern '#(\d+)' -TimeoutSeconds 5
            $result.Matched | Should -Be $true
            $result.Match.Groups[1].Value | Should -Be '99'
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
