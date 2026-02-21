BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:workflowScript = Join-Path $script:repoRoot 'scripts' 'New-FalWorkflow.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force

    # Helper to create a WebException with a response that has a StatusCode property
    if (-not ([System.Management.Automation.PSTypeName]'MockWebResponse').Type) {
        Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Net;
public class MockWebResponse : WebResponse {
    private HttpStatusCode _code;
    public MockWebResponse(HttpStatusCode code) { _code = code; }
    public HttpStatusCode StatusCode { get { return _code; } }
    public override long ContentLength { get { return 0; } set {} }
    public override string ContentType { get { return "application/json"; } set {} }
    public override Uri ResponseUri { get { return new Uri("https://fal.run/mock"); } }
    public override Stream GetResponseStream() { return new MemoryStream(); }
}
"@
    }
}

Describe 'E2E: Error Handling and Retry Scenarios' {
    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'API rate limit (429) with automatic retry' {
        It 'Should retry on 429 and succeed on subsequent attempt' {
            $script:attempt = 0
            Mock Invoke-RestMethod {
                $script:attempt++
                if ($script:attempt -lt 3) {
                    $resp = [MockWebResponse]::new([System.Net.HttpStatusCode]::TooManyRequests)
                    throw [System.Net.WebException]::new(
                        'The remote server returned an error: (429) Too Many Requests.',
                        $null,
                        [System.Net.WebExceptionStatus]::ProtocolError,
                        $resp
                    )
                }
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/retry-ok.png'; width = 1024; height = 1024 })
                    seed   = 42
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = 'Rate limit test' }
                $result.images[0].url | Should -BeLike '*retry-ok*'
                $script:attempt | Should -BeGreaterOrEqual 3
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should fail after exhausting retries on persistent 429' {
            Mock Invoke-RestMethod {
                $resp = [MockWebResponse]::new([System.Net.HttpStatusCode]::TooManyRequests)
                throw [System.Net.WebException]::new(
                    'The remote server returned an error: (429) Too Many Requests.',
                    $null,
                    [System.Net.WebExceptionStatus]::ProtocolError,
                    $resp
                )
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                { Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = 'Persistent rate limit' } } |
                    Should -Throw
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Transient server error (500) with retry' {
        It 'Should retry on 500 and succeed when server recovers' {
            $script:serverAttempt = 0
            Mock Invoke-RestMethod {
                $script:serverAttempt++
                if ($script:serverAttempt -eq 1) {
                    $resp = [MockWebResponse]::new([System.Net.HttpStatusCode]::InternalServerError)
                    throw [System.Net.WebException]::new(
                        'The remote server returned an error: (500) Internal Server Error.',
                        $null,
                        [System.Net.WebExceptionStatus]::ProtocolError,
                        $resp
                    )
                }
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/recovered.png'; width = 1024; height = 1024 })
                    seed   = 7
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = 'Server error test' }
                $result.images[0].url | Should -BeLike '*recovered*'
                $script:serverAttempt | Should -Be 2
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Permanent error (400) with immediate failure' {
        It 'Should fail immediately on 400 without retrying' {
            $script:badRequestCalls = 0
            Mock Invoke-RestMethod {
                $script:badRequestCalls++
                throw [System.Net.WebException]::new(
                    'The remote server returned an error: (400) Bad Request.'
                )
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                { Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = '' } } |
                    Should -Throw
                # 400 is not retryable — should only be called once
                $script:badRequestCalls | Should -Be 1
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Timeout handling in queue polling' {
        It 'Should throw on queue timeout when job never completes' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return [PSCustomObject]@{ request_id = 'req-timeout-err' }
                }
                return [PSCustomObject]@{ status = 'IN_QUEUE'; queue_position = 50 }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                { Wait-FalJob -Model 'fal-ai/flux/dev' -Body @{ prompt = 'Timeout' } -TimeoutSeconds 4 -PollIntervalSeconds 2 } |
                    Should -Throw '*timed out*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should throw on FAILED job status from queue' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return [PSCustomObject]@{ request_id = 'req-job-fail' }
                }
                return [PSCustomObject]@{ status = 'FAILED'; detail = 'GPU out of memory' }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                { Wait-FalJob -Model 'fal-ai/flux/dev' -Body @{ prompt = 'OOM' } -TimeoutSeconds 10 -PollIntervalSeconds 1 } |
                    Should -Throw '*failed*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Invalid API key error path' {
        It 'Should throw when FAL_KEY is not set' {
            $savedKey = $env:FAL_KEY
            Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue
            try {
                { Get-FalApiKey } | Should -Throw '*FAL_KEY*'
            }
            finally {
                if ($savedKey) { $env:FAL_KEY = $savedKey }
            }
        }

        It 'Should throw on 401 Unauthorized from API' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new(
                    'The remote server returned an error: (401) Unauthorized.'
                )
            } -ModuleName FalAi

            $env:FAL_KEY = 'invalid-key-xyz'
            try {
                { Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = 'Auth test' } } |
                    Should -Throw
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Partial workflow recovery' {
        It 'Should report the failing step when a multi-step workflow partially fails' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/partial-ok.png'; width = 1024; height = 1024 })
                        seed   = 1
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    throw [System.Net.WebException]::new('The remote server returned an error: (503) Service Unavailable.')
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'Recovery test' }; dependsOn = @() }
                    @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('generate') }
                )

                $errorThrown = $null
                try {
                    & $script:workflowScript -Name 'recovery-wf' -Steps $steps
                }
                catch {
                    $errorThrown = $_
                }

                $errorThrown | Should -Not -BeNullOrEmpty
                $errorThrown.Exception.Message | Should -BeLike '*Service Unavailable*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should allow retrying from last successful step' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/retried.png'; width = 4096; height = 4096 })
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                # Simulate resume: use saved output from step 1 to retry step 2
                $savedImageUrl = 'https://fal.ai/output/partial-ok.png'
                $retryResult = Invoke-FalApi -Method POST -Endpoint 'fal-ai/aura-sr' -Body @{ image_url = $savedImageUrl }
                $retryResult.images[0].url | Should -BeLike '*retried*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }
}
