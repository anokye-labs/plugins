# InvokeGraphQL.Unit.Tests.ps1
# Pester tests for the _Invoke-GraphQL shared helper

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../../omanfo/skills/okyerema/scripts"
    . (Join-Path $scriptsPath "_Invoke-GraphQL.ps1")
}

Describe "Invoke-GraphQL" {

    Describe "Basic success path" {
        It "Should return parsed JSON when gh returns valid data" {
            $mockJson = '{"data":{"repository":{"name":"test-repo"}}}'
            Mock gh { return $mockJson } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }

            $result = Invoke-GraphQL -Query "{ repository { name } }" -BaseDelayMs 1

            $result.data.repository.name | Should -Be "test-repo"
        }

        It "Should invoke gh exactly once on success" {
            $mockJson = '{"data":{"repository":{"name":"test-repo"}}}'
            Mock gh { return $mockJson } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }

            Invoke-GraphQL -Query "{ repository { name } }" -BaseDelayMs 1

            Should -Invoke gh -Times 1 -Exactly
        }
    }

    Describe "Retry on transient error" {
        It "Should retry and succeed after a transient failure" {
            $script:callCount = 0
            Mock gh {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    throw "server error: 502 Bad Gateway"
                }
                return '{"data":{"ok":true}}'
            } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            $result = Invoke-GraphQL -Query "{ ok }" -MaxAttempts 3 -BaseDelayMs 100

            $result.data.ok | Should -Be $true
        }

        It "Should invoke gh twice when first attempt fails then succeeds" {
            $script:ghCallCount = 0
            Mock gh {
                $script:ghCallCount++
                if ($script:ghCallCount -eq 1) {
                    throw "server error: 502 Bad Gateway"
                }
                return '{"data":{"ok":true}}'
            } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            Invoke-GraphQL -Query "{ ok }" -MaxAttempts 3 -BaseDelayMs 100

            Should -Invoke gh -Times 2 -Exactly
        }
    }

    Describe "Exponential backoff with jitter" {
        It "Should call Start-Sleep with delay in expected range on first retry" {
            $script:sleepValues = @()
            $script:ghAttempt = 0
            Mock gh {
                $script:ghAttempt++
                if ($script:ghAttempt -le 2) {
                    throw "transient error"
                }
                return '{"data":{"ok":true}}'
            } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {
                $script:sleepValues += $Milliseconds
            }

            Invoke-GraphQL -Query "{ ok }" -MaxAttempts 3 -BaseDelayMs 1000

            # First retry: baseDelay = 2^0 * 1000 = 1000, jitter = +/-25% => [750, 1250]
            # But clamped to min 100
            $script:sleepValues[0] | Should -BeGreaterOrEqual 750
            $script:sleepValues[0] | Should -BeLessOrEqual 1250
        }

        It "Should double the base delay on the second retry" {
            $script:sleepValues = @()
            $script:ghAttempt = 0
            Mock gh {
                $script:ghAttempt++
                if ($script:ghAttempt -le 3) {
                    throw "transient error"
                }
                return '{"data":{"ok":true}}'
            } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {
                $script:sleepValues += $Milliseconds
            }

            Invoke-GraphQL -Query "{ ok }" -MaxAttempts 4 -BaseDelayMs 1000

            # Second retry: baseDelay = 2^1 * 1000 = 2000, jitter = +/-25% => [1500, 2500]
            $script:sleepValues[1] | Should -BeGreaterOrEqual 1500
            $script:sleepValues[1] | Should -BeLessOrEqual 2500
        }

        It "Should enforce minimum sleep of 100ms" {
            $script:sleepValues = @()
            $script:ghAttempt = 0
            Mock gh {
                $script:ghAttempt++
                if ($script:ghAttempt -eq 1) {
                    throw "transient error"
                }
                return '{"data":{"ok":true}}'
            } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {
                $script:sleepValues += $Milliseconds
            }

            # Very small base delay to test the Min(100, ...) floor
            Invoke-GraphQL -Query "{ ok }" -MaxAttempts 2 -BaseDelayMs 10

            $script:sleepValues[0] | Should -BeGreaterOrEqual 100
        }
    }

    Describe "Non-retryable errors" {
        It "Should throw immediately on NOT_FOUND without retrying" {
            Mock gh { throw "GraphQL error: NOT_FOUND" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 3 -BaseDelayMs 1 } | Should -Throw

            Should -Invoke gh -Times 1 -Exactly
        }

        It "Should throw immediately on FORBIDDEN without retrying" {
            Mock gh { throw "GraphQL error: FORBIDDEN" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 3 -BaseDelayMs 1 } | Should -Throw

            Should -Invoke gh -Times 1 -Exactly
        }

        It "Should throw immediately on UNAUTHORIZED without retrying" {
            Mock gh { throw "GraphQL error: UNAUTHORIZED" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 3 -BaseDelayMs 1 } | Should -Throw

            Should -Invoke gh -Times 1 -Exactly
        }

        It "Should throw immediately on INSUFFICIENT_SCOPES without retrying" {
            Mock gh { throw "GraphQL error: INSUFFICIENT_SCOPES" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 3 -BaseDelayMs 1 } | Should -Throw

            Should -Invoke gh -Times 1 -Exactly
        }
    }

    Describe "Validation errors" {
        It "Should throw immediately on 'Variable was defined' error" {
            Mock gh { throw 'Variable $owner was defined but not used' } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 3 -BaseDelayMs 1 } | Should -Throw

            Should -Invoke gh -Times 1 -Exactly
        }

        It "Should throw immediately on 'parse error'" {
            Mock gh { throw "parse error at line 1: unexpected token" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ bad query" -MaxAttempts 3 -BaseDelayMs 1 } | Should -Throw

            Should -Invoke gh -Times 1 -Exactly
        }

        It "Should throw immediately on 'syntax error'" {
            Mock gh { throw "syntax error in GraphQL query" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ bad }" -MaxAttempts 3 -BaseDelayMs 1 } | Should -Throw

            Should -Invoke gh -Times 1 -Exactly
        }

        It "Should throw immediately on 'argument has invalid value'" {
            Mock gh { throw "argument owner has invalid value: null" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 3 -BaseDelayMs 1 } | Should -Throw

            Should -Invoke gh -Times 1 -Exactly
        }
    }

    Describe "Max attempts exhausted" {
        It "Should throw after all attempts are used up" {
            Mock gh { throw "server error: 500 Internal Server Error" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 3 -BaseDelayMs 100 } | Should -Throw
        }

        It "Should invoke gh exactly MaxAttempts times before giving up" {
            Mock gh { throw "server error: 500 Internal Server Error" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            try { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 3 -BaseDelayMs 100 } catch {}

            Should -Invoke gh -Times 3 -Exactly
        }

        It "Should call Start-Sleep exactly MaxAttempts minus 1 times" {
            Mock gh { throw "server error: 500 Internal Server Error" } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            try { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 3 -BaseDelayMs 100 } catch {}

            # Sleeps happen between retries: after attempt 1 and attempt 2, not after the last
            Should -Invoke Start-Sleep -Times 2 -Exactly
        }
    }

    Describe "GraphQL errors in response" {
        It "Should throw when response contains errors array" {
            $errorJson = '{"errors":[{"message":"Could not resolve field"}]}'
            Mock gh { return $errorJson } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ bad }" -MaxAttempts 1 -BaseDelayMs 1 } | Should -Throw "*GraphQL errors*Could not resolve field*"
        }

        It "Should join multiple error messages with semicolons" {
            $errorJson = '{"errors":[{"message":"Error one"},{"message":"Error two"}]}'
            Mock gh { return $errorJson } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ bad }" -MaxAttempts 1 -BaseDelayMs 1 } | Should -Throw "*Error one; Error two*"
        }

        It "Should treat GraphQL errors as retryable by default" {
            $script:errorCallCount = 0
            $errorJson = '{"errors":[{"message":"Something went wrong"}]}'
            Mock gh {
                $script:errorCallCount++
                if ($script:errorCallCount -le 2) {
                    return $errorJson
                }
                return '{"data":{"ok":true}}'
            } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            $result = Invoke-GraphQL -Query "{ ok }" -MaxAttempts 3 -BaseDelayMs 100

            $result.data.ok | Should -Be $true
            Should -Invoke gh -Times 3 -Exactly
        }
    }

    Describe "Custom headers" {
        It "Should pass -H args to gh when Headers parameter is provided" {
            $mockJson = '{"data":{"ok":true}}'
            Mock gh { return $mockJson } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }

            Invoke-GraphQL -Query "{ ok }" -Headers @{ "X-Custom" = "value1" } -BaseDelayMs 1

            Should -Invoke gh -Times 1 -Exactly -ParameterFilter {
                $args -contains '-H'
            }
        }

        It "Should format header as 'Key: Value'" {
            $script:capturedArgs = $null
            Mock gh {
                $script:capturedArgs = $args
                return '{"data":{"ok":true}}'
            } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }

            Invoke-GraphQL -Query "{ ok }" -Headers @{ "Accept" = "application/json" } -BaseDelayMs 1

            $hIndex = [array]::IndexOf($script:capturedArgs, '-H')
            $hIndex | Should -BeGreaterOrEqual 0
            $script:capturedArgs[$hIndex + 1] | Should -Be "Accept: application/json"
        }

        It "Should not pass -H args when Headers is empty" {
            $script:capturedArgs = $null
            Mock gh {
                $script:capturedArgs = $args
                return '{"data":{"ok":true}}'
            } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }

            Invoke-GraphQL -Query "{ ok }" -BaseDelayMs 1

            $script:capturedArgs | Should -Not -Contain '-H'
        }
    }

    Describe "Non-zero exit code handling" {
        It "Should throw when gh returns non-zero exit code" {
            Mock gh {
                $global:LASTEXITCODE = 1
                return "gh: not logged in"
            } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
            Mock Start-Sleep {}

            { Invoke-GraphQL -Query "{ repo }" -MaxAttempts 1 -BaseDelayMs 1 } | Should -Throw "*exit code*"
        }

        AfterAll {
            # Reset LASTEXITCODE to avoid polluting subsequent test files
            $global:LASTEXITCODE = 0
        }
    }
}
