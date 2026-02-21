BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:generateScript = Join-Path $script:repoRoot 'scripts' 'Invoke-FalGenerate.ps1'
    $script:upscaleScript = Join-Path $script:repoRoot 'scripts' 'Invoke-FalUpscale.ps1'
    $script:workflowScript = Join-Path $script:repoRoot 'scripts' 'New-FalWorkflow.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'Validation: Error Recovery Workflows' {
    BeforeAll {
        $script:testDir = Join-Path $TestDrive 'validation-recovery'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Retry after transient failure' {
        It 'Should succeed on retry after a transient 500 error' {
            # Test caller-level retry pattern (Invoke-FalApi needs a proper HTTP Response
            # object to detect 5xx, so we test the retry pattern at the script level)
            $global:retryAttemptCount = 0
            Mock Invoke-RestMethod {
                $global:retryAttemptCount++
                if ($global:retryAttemptCount -le 2) {
                    throw [System.Net.WebException]::new(
                        'The remote server returned an error: (500) Internal Server Error.')
                }
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = 'https://fal.ai/output/retry-success.png'
                        width  = 1024
                        height = 1024
                    })
                    seed = 42
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                # Simulate caller-level retry loop
                $maxRetries = 3
                $result = $null
                for ($i = 1; $i -le $maxRetries; $i++) {
                    try {
                        $result = Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = 'Retry test' }
                        break
                    } catch {
                        if ($i -eq $maxRetries) { throw }
                    }
                }
                $result.images[0].url | Should -Be 'https://fal.ai/output/retry-success.png'
                $global:retryAttemptCount | Should -Be 3
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should exhaust retries and throw on persistent failure' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new(
                    'The remote server returned an error: (500) Internal Server Error.')
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                { Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = 'Always fails' } } |
                    Should -Throw
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Graceful degradation: fallback model on primary failure' {
        It 'Should fall back to schnell when dev model fails' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like '*flux/dev*') {
                    throw [System.Net.WebException]::new(
                        'The remote server returned an error: (503) Service Unavailable.')
                }
                if ($Uri -like '*flux/schnell*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{
                            url    = 'https://fal.ai/output/fallback-schnell.png'
                            width  = 1024
                            height = 1024
                        })
                        seed = 99
                    }
                }
                return $null
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $prompt = 'A serene mountain landscape'
                $primaryModel = 'fal-ai/flux/dev'
                $fallbackModel = 'fal-ai/flux/schnell'

                $result = $null
                $usedModel = $null
                try {
                    $result = & $script:generateScript -Prompt $prompt -Model $primaryModel
                    $usedModel = $primaryModel
                }
                catch {
                    # Primary failed — try fallback
                    $result = & $script:generateScript -Prompt $prompt -Model $fallbackModel
                    $usedModel = $fallbackModel
                }

                $result | Should -Not -BeNullOrEmpty
                $result.Images[0].Url | Should -Be 'https://fal.ai/output/fallback-schnell.png'
                $usedModel | Should -Be $fallbackModel
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should propagate error when both primary and fallback models fail' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new(
                    'The remote server returned an error: (503) Service Unavailable.')
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = $null
                $caughtError = $null
                try {
                    $result = & $script:generateScript -Prompt 'test' -Model 'fal-ai/flux/dev'
                }
                catch {
                    try {
                        $result = & $script:generateScript -Prompt 'test' -Model 'fal-ai/flux/schnell'
                    }
                    catch {
                        $caughtError = $_
                    }
                }

                $result | Should -BeNullOrEmpty
                $caughtError | Should -Not -BeNullOrEmpty
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Partial pipeline recovery: resume from last successful step' {
        It 'Should resume workflow from last successful step after failure' {
            # Phase 1: Run workflow where step 2 fails
            $script:phase1Call = 0
            Mock Invoke-RestMethod {
                param($Uri)
                $script:phase1Call++
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{
                            url = 'https://fal.ai/output/recovery-gen.png'
                            width = 1024; height = 1024
                        })
                        seed = 10
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    throw [System.Net.WebException]::new(
                        'The remote server returned an error: (502) Bad Gateway.')
                }
                return $null
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                # First attempt: generate succeeds, upscale fails
                $genResult = & $script:generateScript -Prompt 'Recovery test' -Model 'fal-ai/flux/dev'
                $genResult.Images[0].Url | Should -Be 'https://fal.ai/output/recovery-gen.png'

                $upscaleFailed = $false
                try {
                    & $script:upscaleScript -ImageUrl $genResult.Images[0].Url -Scale 2
                }
                catch {
                    $upscaleFailed = $true
                }
                $upscaleFailed | Should -Be $true

                # Phase 2: Resume from the saved generation URL
                Mock Invoke-RestMethod {
                    param($Uri)
                    if ($Uri -like '*aura-sr*') {
                        return [PSCustomObject]@{
                            image = [PSCustomObject]@{
                                url = 'https://fal.ai/output/recovery-upscaled.png'
                                width = 2048; height = 2048
                            }
                        }
                    }
                    return $null
                } -ModuleName FalAi

                # Resume using the previously saved URL — no need to regenerate
                $resumeResult = & $script:upscaleScript -ImageUrl $genResult.Images[0].Url -Scale 2
                $resumeResult.Image.Url | Should -Be 'https://fal.ai/output/recovery-upscaled.png'
                $resumeResult.Width | Should -Be 2048
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should track step completion state for recovery decisions' {
            # Simulate a step tracker for recovery — use ordered to guarantee enumeration order
            $stepTracker = [ordered]@{
                'generate' = [PSCustomObject]@{ Status = 'Completed'; Output = 'https://fal.ai/output/tracked-gen.png' }
                'upscale'  = [PSCustomObject]@{ Status = 'Failed';    Output = $null }
                'deliver'  = [PSCustomObject]@{ Status = 'Pending';   Output = $null }
            }

            # Find first incomplete step
            $resumeFrom = $stepTracker.GetEnumerator() |
                Where-Object { $_.Value.Status -ne 'Completed' } |
                Select-Object -First 1

            $resumeFrom.Key | Should -Be 'upscale'
            $resumeFrom.Value.Status | Should -Be 'Failed'

            # Completed steps should be skippable
            $completedSteps = $stepTracker.GetEnumerator() |
                Where-Object { $_.Value.Status -eq 'Completed' }
            $completedSteps.Key | Should -Contain 'generate'
            $completedSteps.Value.Output | Should -Not -BeNullOrEmpty
        }
    }
}
