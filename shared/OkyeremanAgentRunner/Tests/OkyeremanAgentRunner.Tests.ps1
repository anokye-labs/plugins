# OkyeremanAgentRunner.Tests.ps1
# Pester tests for the OkyeremanAgentRunner module

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "../OkyeremanAgentRunner.psd1"
    Import-Module $modulePath -Force
}

Describe "OkyeremanAgentRunner Module" {
    It "Should import the module successfully" {
        $module = Get-Module OkyeremanAgentRunner
        $module | Should -Not -BeNullOrEmpty
        $module.Name | Should -Be "OkyeremanAgentRunner"
    }

    It "Should export all expected functions" {
        $expectedFunctions = @(
            'Write-AgentLog',
            'Invoke-GraphQL',
            'Invoke-WithRetry',
            'New-AgentError',
            'Get-IssueContext',
            'Clear-IssueContextCache',
            'New-AgentPR',
            'Get-PRStatus',
            'Add-PRReviewComment',
            'ConvertTo-SafeOutput',
            'Limit-OutputLength',
            'ConvertTo-GitHubMarkdown',
            'New-CorrelationId',
            'Set-CorrelationId',
            'Get-CorrelationId'
        )

        $module = Get-Module OkyeremanAgentRunner
        $exportedFunctions = $module.ExportedFunctions.Keys

        foreach ($func in $expectedFunctions) {
            $exportedFunctions | Should -Contain $func
        }
    }
}

Describe "Logging Functions" {
    Context "Write-AgentLog" {
        It "Should write log with default level Info" {
            { Write-AgentLog -Message "Test message" } | Should -Not -Throw
        }

        It "Should accept all valid log levels" {
            $levels = @('Debug', 'Info', 'Warn', 'Error')
            foreach ($level in $levels) {
                { Write-AgentLog -Message "Test" -Level $level } | Should -Not -Throw
            }
        }

        It "Should return PSCustomObject when AsObject is specified" {
            $result = Write-AgentLog -Message "Test" -AsObject
            $result | Should -BeOfType [PSCustomObject]
            $result.Message | Should -Be "Test"
            $result.Level | Should -Be "Info"
            $result.Timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include correlation ID when provided" {
            $result = Write-AgentLog -Message "Test" -CorrelationId "test-123" -AsObject
            $result.CorrelationId | Should -Be "test-123"
        }

        It "Should include agent name when provided" {
            $result = Write-AgentLog -Message "Test" -Agent "TestAgent" -AsObject
            $result.Agent | Should -Be "TestAgent"
        }
    }
}

Describe "GraphQL Functions" {
    Context "Invoke-GraphQL" {
        It "Should have required Query parameter" {
            $cmd = Get-Command Invoke-GraphQL
            $cmd.Parameters.Keys | Should -Contain 'Query'
        }

        It "Should have SubIssues switch parameter" {
            $cmd = Get-Command Invoke-GraphQL
            $cmd.Parameters.Keys | Should -Contain 'SubIssues'
        }

        It "Should have AdditionalHeaders parameter" {
            $cmd = Get-Command Invoke-GraphQL
            $cmd.Parameters.Keys | Should -Contain 'AdditionalHeaders'
        }

        It "Should have retry parameters" {
            $cmd = Get-Command Invoke-GraphQL
            $cmd.Parameters.Keys | Should -Contain 'MaxRetries'
            $cmd.Parameters.Keys | Should -Contain 'InitialDelaySeconds'
            $cmd.Parameters.Keys | Should -Contain 'BackoffMultiplier'
            $cmd.Parameters.Keys | Should -Contain 'MaxDelaySeconds'
        }

        It "Should return parsed JSON when gh succeeds" {
            # Mock gh to return a simple JSON response
            Mock gh {
                $global:LASTEXITCODE = 0
                '{"data":{"viewer":{"login":"testuser"}}}'
            } -ModuleName OkyeremanAgentRunner

            $result = Invoke-GraphQL -Query 'query { viewer { login } }'
            $result.data.viewer.login | Should -Be 'testuser'
        }

        It "Should throw when gh exits with non-zero code" {
            Mock gh {
                $global:LASTEXITCODE = 1
                'gh: some error'
            } -ModuleName OkyeremanAgentRunner

            { Invoke-GraphQL -Query 'query { viewer { login } }' -MaxRetries 0 } | Should -Throw
        }

        It "Should throw when response contains GraphQL errors" {
            Mock gh {
                $global:LASTEXITCODE = 0
                '{"errors":[{"message":"Field does not exist"}]}'
            } -ModuleName OkyeremanAgentRunner

            { Invoke-GraphQL -Query 'query { bad { field } }' -MaxRetries 0 } | Should -Throw -ExpectedMessage '*GraphQL errors*'
        }

        It "Should retry on transient failure and succeed" {
            $script:callCount = 0
            Mock gh {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $global:LASTEXITCODE = 1
                    'transient error'
                }
                else {
                    $global:LASTEXITCODE = 0
                    '{"data":{"viewer":{"login":"ok"}}}'
                }
            } -ModuleName OkyeremanAgentRunner

            $result = Invoke-GraphQL -Query 'query { viewer { login } }' -MaxRetries 3 -InitialDelaySeconds 0
            $result.data.viewer.login | Should -Be 'ok'
            $script:callCount | Should -BeGreaterThan 1
        }

        It "Should throw after exhausting retries" {
            Mock gh {
                $global:LASTEXITCODE = 1
                'persistent error'
            } -ModuleName OkyeremanAgentRunner

            { Invoke-GraphQL -Query 'query { viewer { login } }' -MaxRetries 2 -InitialDelaySeconds 0 } | Should -Throw
        }

        It "Should pass GraphQL-Features header when SubIssues is set" {
            $script:capturedArgs = $null
            Mock gh {
                param([Parameter(ValueFromRemainingArguments)][string[]]$args)
                $script:capturedArgs = $args
                $global:LASTEXITCODE = 0
                '{"data":{}}'
            } -ModuleName OkyeremanAgentRunner

            Invoke-GraphQL -Query 'query { viewer { login } }' -SubIssues
            $script:capturedArgs -join ' ' | Should -Match 'GraphQL-Features'
            $script:capturedArgs -join ' ' | Should -Match 'sub_issues'
        }

        It "Should pass additional headers when provided" {
            $script:capturedArgs = $null
            Mock gh {
                param([Parameter(ValueFromRemainingArguments)][string[]]$args)
                $script:capturedArgs = $args
                $global:LASTEXITCODE = 0
                '{"data":{}}'
            } -ModuleName OkyeremanAgentRunner

            Invoke-GraphQL -Query 'query { viewer { login } }' -AdditionalHeaders @{ 'X-Test' = 'value' }
            $script:capturedArgs -join ' ' | Should -Match 'X-Test'
        }

        It "Should detect rate limit in error text and retry" {
            $script:callCount = 0
            Mock gh {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $global:LASTEXITCODE = 1
                    'You have exceeded a secondary rate limit'
                }
                else {
                    $global:LASTEXITCODE = 0
                    '{"data":{"viewer":{"login":"recovered"}}}'
                }
            } -ModuleName OkyeremanAgentRunner

            # Override Start-Sleep to avoid waiting in tests
            Mock Start-Sleep {} -ModuleName OkyeremanAgentRunner

            $result = Invoke-GraphQL -Query 'query { viewer { login } }' -MaxRetries 3 -InitialDelaySeconds 0
            $result.data.viewer.login | Should -Be 'recovered'
        }

        It "Should detect rate limit in GraphQL errors array and retry" {
            $script:callCount = 0
            Mock gh {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $global:LASTEXITCODE = 0
                    '{"errors":[{"message":"You have exceeded a secondary rate limit"}]}'
                }
                else {
                    $global:LASTEXITCODE = 0
                    '{"data":{"viewer":{"login":"recovered"}}}'
                }
            } -ModuleName OkyeremanAgentRunner

            Mock Start-Sleep {} -ModuleName OkyeremanAgentRunner

            $result = Invoke-GraphQL -Query 'query { viewer { login } }' -MaxRetries 3 -InitialDelaySeconds 0
            $result.data.viewer.login | Should -Be 'recovered'
        }
    }
}

Describe "Error Handling Functions" {
    Context "Invoke-WithRetry" {
        It "Should execute script block successfully" {
            $result = Invoke-WithRetry -ScriptBlock { "Success" } -MaxRetries 3
            $result | Should -Be "Success"
        }

        It "Should retry on failure and eventually succeed" {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Temporary failure"
                }
                return "Success after retry"
            } -MaxRetries 3 -InitialDelaySeconds 1

            $result | Should -Be "Success after retry"
            $script:attemptCount | Should -BeGreaterThan 1
        }

        It "Should throw after max retries exhausted" {
            {
                Invoke-WithRetry -ScriptBlock {
                    throw "Persistent failure"
                } -MaxRetries 2 -InitialDelaySeconds 1
            } | Should -Throw
        }

        It "Should accept backoff parameters" {
            $result = Invoke-WithRetry -ScriptBlock { "Success" } `
                -MaxRetries 5 `
                -InitialDelaySeconds 1 `
                -BackoffMultiplier 2 `
                -MaxDelaySeconds 30

            $result | Should -Be "Success"
        }

        It "Should throw after exhausting retries on rate limit" {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    $ex = New-Object System.Exception 'rate limit exceeded'
                    throw $ex
                } -MaxRetries 1
            } | Should -Throw
            $script:attemptCount | Should -BeGreaterThan 1
        }
    }

    Context "New-AgentError" {
        It "Should create structured error object" {
            $error = New-AgentError -Message "Test error" -ErrorCode "TestError"
            $error | Should -BeOfType [PSCustomObject]
            $error.Success | Should -Be $false
            $error.Message | Should -Be "Test error"
            $error.ErrorCode | Should -Be "TestError"
        }

        It "Should include timestamp" {
            $error = New-AgentError -Message "Test" -ErrorCode "Code"
            $error.Timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should accept optional details" {
            $error = New-AgentError -Message "Test" -ErrorCode "Code" -Details "Additional info"
            $error.Details | Should -Be "Additional info"
        }
    }
}

Describe "Issue Context Functions" {
    Context "Get-IssueContext" {
        It "Should have required parameters" {
            $cmd = Get-Command Get-IssueContext
            $cmd.Parameters.Keys | Should -Contain "Owner"
            $cmd.Parameters.Keys | Should -Contain "Repo"
            $cmd.Parameters.Keys | Should -Contain "IssueNumber"
        }

        It "Should support UseCache parameter" {
            $cmd = Get-Command Get-IssueContext
            $cmd.Parameters.Keys | Should -Contain "UseCache"
        }
    }

    Context "Clear-IssueContextCache" {
        It "Should not throw when clearing cache" {
            { Clear-IssueContextCache } | Should -Not -Throw
        }
    }
}

Describe "PR Management Functions" {
    Context "New-AgentPR" {
        It "Should have required parameters" {
            $cmd = Get-Command New-AgentPR
            $cmd.Parameters.Keys | Should -Contain "Owner"
            $cmd.Parameters.Keys | Should -Contain "Repo"
            $cmd.Parameters.Keys | Should -Contain "Title"
            $cmd.Parameters.Keys | Should -Contain "Body"
        }

        It "Should support optional parameters" {
            $cmd = Get-Command New-AgentPR
            $cmd.Parameters.Keys | Should -Contain "Base"
            $cmd.Parameters.Keys | Should -Contain "Head"
            $cmd.Parameters.Keys | Should -Contain "IssueNumber"
        }
    }

    Context "Get-PRStatus" {
        It "Should have required parameters" {
            $cmd = Get-Command Get-PRStatus
            $cmd.Parameters.Keys | Should -Contain "Owner"
            $cmd.Parameters.Keys | Should -Contain "Repo"
            $cmd.Parameters.Keys | Should -Contain "PullNumber"
        }
    }

    Context "Add-PRReviewComment" {
        It "Should have required parameters" {
            $cmd = Get-Command Add-PRReviewComment
            $cmd.Parameters.Keys | Should -Contain "Owner"
            $cmd.Parameters.Keys | Should -Contain "Repo"
            $cmd.Parameters.Keys | Should -Contain "PullNumber"
            $cmd.Parameters.Keys | Should -Contain "Body"
        }

        It "Should accept valid Event types" {
            $cmd = Get-Command Add-PRReviewComment
            $eventParam = $cmd.Parameters['Event']
            $eventParam.Attributes.ValidValues | Should -Contain 'COMMENT'
            $eventParam.Attributes.ValidValues | Should -Contain 'APPROVE'
            $eventParam.Attributes.ValidValues | Should -Contain 'REQUEST_CHANGES'
        }
    }
}

Describe "Safe Output Processing Functions" {
    Context "ConvertTo-SafeOutput" {
        It "Should redact GitHub personal access tokens" {
            $input = "My token is ghp_1234567890abcdefghijklmnopqrstuv"
            $output = ConvertTo-SafeOutput -Text $input
            $output | Should -Not -Match "ghp_1234567890"
            $output | Should -Match "\[REDACTED\]"
        }

        It "Should redact email addresses" {
            $input = "Contact me at user@example.com for details"
            $output = ConvertTo-SafeOutput -Text $input
            $output | Should -Not -Match "user@example.com"
            $output | Should -Match "\[REDACTED\]"
        }

        It "Should redact phone numbers" {
            $input = "Call me at 555-123-4567"
            $output = ConvertTo-SafeOutput -Text $input
            $output | Should -Not -Match "555-123-4567"
            $output | Should -Match "\[REDACTED\]"
        }

        It "Should redact github_pat_ tokens" {
            $input = "Token: github_pat_1234567890abcdefghijklmnopqrstuvwxyz"
            $output = ConvertTo-SafeOutput -Text $input
            $output | Should -Not -Match "github_pat_"
            $output | Should -Match "\[REDACTED\]"
        }

        It "Should support custom redaction marker" {
            $input = "Token: ghp_1234567890abcdefghijklmnopqrstuv"
            $output = ConvertTo-SafeOutput -Text $input -RedactionMarker "***"
            $output | Should -Match "\*\*\*"
        }

        It "Should handle pipeline input" {
            $output = "ghp_1234567890abcdefghijklmnopqrstuv" | ConvertTo-SafeOutput
            $output | Should -Match "\[REDACTED\]"
        }

        It "Should escape regex backreferences in RedactionMarker" {
            $input = "Token: ghp_1234567890abcdefghijklmnopqrstuv"
            $output = ConvertTo-SafeOutput -Text $input -RedactionMarker '$0'
            # Should NOT contain the original token (which $0 would expand to)
            $output | Should -Not -Match "ghp_"
            # Should contain literal $0
            $output | Should -Match '\$0'
        }
    }

    Context "Limit-OutputLength" {
        It "Should not truncate short text" {
            $input = "Short text"
            $output = Limit-OutputLength -Text $input -MaxLength 100
            $output | Should -Be $input
        }

        It "Should truncate long text" {
            $input = "a" * 1000
            $output = Limit-OutputLength -Text $input -MaxLength 100
            $output.Length | Should -Be 100
            $output | Should -Match '\.\.\.$'
        }

        It "Should support custom ellipsis" {
            $input = "a" * 1000
            $output = Limit-OutputLength -Text $input -MaxLength 100 -Ellipsis "[truncated]"
            $output | Should -Match '\[truncated\]$'
        }

        It "Should handle pipeline input" {
            $output = ("a" * 1000) | Limit-OutputLength -MaxLength 50
            $output.Length | Should -Be 50
        }

        It "Should handle small MaxLength gracefully" {
            $output = Limit-OutputLength -Text "Hello World" -MaxLength 2 -Ellipsis "..."
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match '\.\.\.'
        }

        It "Should handle MaxLength equal to Ellipsis length" {
            $output = Limit-OutputLength -Text "Hello World" -MaxLength 3 -Ellipsis "..."
            $output | Should -Be "..."
        }
    }

    Context "ConvertTo-GitHubMarkdown" {
        It "Should return plain text by default" {
            $input = "Plain text"
            $output = ConvertTo-GitHubMarkdown -Text $input
            $output | Should -Be $input
        }

        It "Should wrap in inline code" {
            $input = "code snippet"
            $output = ConvertTo-GitHubMarkdown -Text $input -Format Code
            $output | Should -Be "``code snippet``"
        }

        It "Should create code block" {
            $input = "Get-Process"
            $output = ConvertTo-GitHubMarkdown -Text $input -Format CodeBlock
            $output | Should -Match '^```'
            $output | Should -Match 'Get-Process'
            $output | Should -Match '```$'
        }

        It "Should create code block with language" {
            $input = "Write-Host 'test'"
            $output = ConvertTo-GitHubMarkdown -Text $input -Format CodeBlock -Language powershell
            $output | Should -Match '^```powershell'
        }

        It "Should create quote" {
            $input = "Important note"
            $output = ConvertTo-GitHubMarkdown -Text $input -Format Quote
            $output | Should -Match '^> Important note'
        }

        It "Should handle multi-line quotes" {
            $input = "Line 1`nLine 2"
            $output = ConvertTo-GitHubMarkdown -Text $input -Format Quote
            $output | Should -Match '^> Line 1'
            $output | Should -Match '> Line 2'
        }

        It "Should handle pipeline input" {
            $output = "test" | ConvertTo-GitHubMarkdown -Format Code
            $output | Should -Be "``test``"
        }
    }
}

Describe "Correlation Tracking Functions" {
    Context "New-CorrelationId" {
        It "Should generate a correlation ID" {
            $cid = New-CorrelationId
            $cid | Should -Not -BeNullOrEmpty
            $cid | Should -Match '^agent-\d{14}-\d{4}$'
        }

        It "Should support custom prefix" {
            $cid = New-CorrelationId -Prefix "asafo"
            $cid | Should -Match '^asafo-\d{14}-\d{4}$'
        }

        It "Should generate unique IDs" {
            $cid1 = New-CorrelationId
            Start-Sleep -Milliseconds 100
            $cid2 = New-CorrelationId
            $cid1 | Should -Not -Be $cid2
        }
    }

    Context "Set-CorrelationId and Get-CorrelationId" {
        It "Should store and retrieve correlation ID" {
            $testCid = "test-correlation-123"
            Set-CorrelationId -CorrelationId $testCid
            $retrieved = Get-CorrelationId -AutoGenerate:$false
            $retrieved | Should -Be $testCid
        }

        It "Should auto-generate if none exists" {
            # Clear by setting to null (simulate fresh session)
            Set-CorrelationId -CorrelationId ""
            $cid = Get-CorrelationId -AutoGenerate:$true
            $cid | Should -Not -BeNullOrEmpty
        }

        It "Should return null if no ID and AutoGenerate is false" {
            Set-CorrelationId -CorrelationId ""
            $cid = Get-CorrelationId -AutoGenerate:$false
            $cid | Should -BeNullOrEmpty
        }
    }
}

Describe "Integration Tests" {
    Context "Logging with Correlation Tracking" {
        It "Should log with auto-generated correlation ID" {
            $cid = New-CorrelationId -Prefix "test"
            $log = Write-AgentLog -Message "Integration test" -CorrelationId $cid -AsObject
            $log.CorrelationId | Should -Be $cid
        }
    }

    Context "Error Handling with Logging" {
        It "Should log retry attempts" {
            $script:attempts = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attempts++
                    if ($script:attempts -lt 2) {
                        throw "Retry test"
                    }
                    Write-AgentLog "Retry succeeded" -Level Info
                } -MaxRetries 3 -InitialDelaySeconds 1
            } | Should -Not -Throw
        }
    }

    Context "Safe Output Processing Pipeline" {
        It "Should chain sanitize and truncate operations" {
            $input = "Token: ghp_1234567890abcdefghijklmnopqrstuv" + ("a" * 1000)
            $output = $input | ConvertTo-SafeOutput | Limit-OutputLength -MaxLength 100
            $output | Should -Match "\[REDACTED\]"
            $output.Length | Should -BeLessOrEqual 100
        }

        It "Should sanitize and format as markdown" {
            $code = "API_KEY=ghp_1234567890abcdefghijklmnopqrstuv"
            $output = $code | ConvertTo-SafeOutput | ConvertTo-GitHubMarkdown -Format CodeBlock
            $output | Should -Match "\[REDACTED\]"
            $output | Should -Match '^```'
        }
    }
}

AfterAll {
    # Clean up
    Remove-Module OkyeremanAgentRunner -ErrorAction SilentlyContinue
}
