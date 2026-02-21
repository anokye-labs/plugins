BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:queueScript = Join-Path $script:repoRoot 'scripts' 'Get-QueueStatus.ps1'
    $script:generateScript = Join-Path $script:repoRoot 'scripts' 'Invoke-FalGenerate.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'E2E: Queue Management' {
    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Submit job and poll until complete' {
        It 'Should submit a job to queue and receive a request ID' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return [PSCustomObject]@{ request_id = 'req-queue-001' }
                }
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/queued.png'; width = 1024; height = 1024 })
                    seed   = 42
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:generateScript -Prompt 'Queued landscape' -Queue
                $result.Images.Count | Should -Be 1
                $result.Images[0].Url | Should -BeLike '*queued*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should poll through IN_QUEUE and IN_PROGRESS before COMPLETED' {
            $script:pollCount = 0
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -like '*queue*') {
                    return [PSCustomObject]@{ request_id = 'req-queue-002' }
                }
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    $script:pollCount++
                    $s = switch ($script:pollCount) {
                        1 { 'IN_QUEUE' }
                        2 { 'IN_PROGRESS' }
                        default { 'COMPLETED' }
                    }
                    return [PSCustomObject]@{ status = $s; queue_position = if ($script:pollCount -eq 1) { 3 } else { $null } }
                }
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/polled.png'; width = 1024; height = 1024 })
                    seed   = 7
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:generateScript -Prompt 'Polling test' -Queue
                $result.Images.Count | Should -Be 1
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Queue position tracking' {
        It 'Should report queue position via Get-QueueStatus' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    status         = 'IN_QUEUE'
                    queue_position = 5
                    response_url   = 'https://queue.fal.run/fal-ai/flux/dev/requests/req-pos-001'
                    logs           = @()
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $status = & $script:queueScript -RequestId 'req-pos-001' -Model 'fal-ai/flux/dev'
                $status.Status | Should -Be 'IN_QUEUE'
                $status.QueuePosition | Should -Be 5
                $status.RequestId | Should -Be 'req-pos-001'
                $status.Model | Should -Be 'fal-ai/flux/dev'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should report IN_PROGRESS status with no queue position' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    status         = 'IN_PROGRESS'
                    queue_position = $null
                    response_url   = $null
                    logs           = @('Starting inference...')
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $status = & $script:queueScript -RequestId 'req-prog-001' -Model 'fal-ai/flux/dev'
                $status.Status | Should -Be 'IN_PROGRESS'
                $status.QueuePosition | Should -BeNullOrEmpty
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should report COMPLETED status' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    status         = 'COMPLETED'
                    queue_position = $null
                    response_url   = 'https://queue.fal.run/fal-ai/flux/dev/requests/req-done-001'
                    logs           = @('Completed in 4.2s')
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $status = & $script:queueScript -RequestId 'req-done-001' -Model 'fal-ai/flux/dev'
                $status.Status | Should -Be 'COMPLETED'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Timeout handling' {
        It 'Should throw on job timeout' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return [PSCustomObject]@{ request_id = 'req-timeout-001' }
                }
                # Always return IN_QUEUE to force timeout
                return [PSCustomObject]@{ status = 'IN_QUEUE'; queue_position = 99 }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $body = @{ prompt = 'Timeout test' }
                { Wait-FalJob -Model 'fal-ai/flux/dev' -Body $body -TimeoutSeconds 4 -PollIntervalSeconds 2 } |
                    Should -Throw '*timed out*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should throw on FAILED job status' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return [PSCustomObject]@{ request_id = 'req-fail-001' }
                }
                return [PSCustomObject]@{ status = 'FAILED'; detail = 'Model inference error: OOM' }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $body = @{ prompt = 'Failure test' }
                { Wait-FalJob -Model 'fal-ai/flux/dev' -Body $body -TimeoutSeconds 10 -PollIntervalSeconds 1 } |
                    Should -Throw '*failed*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Concurrent queue submissions' {
        It 'Should handle multiple independent queue jobs' {
            $requestCounter = 0
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -like '*queue*') {
                    $requestCounter++
                    return [PSCustomObject]@{ request_id = "req-concurrent-$requestCounter" }
                }
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = "https://fal.ai/output/concurrent-$requestCounter.png"; width = 1024; height = 1024 })
                    seed   = $requestCounter
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $jobs = @(
                    @{ prompt = 'Mountain sunrise'; model = 'fal-ai/flux/dev' }
                    @{ prompt = 'Ocean sunset';     model = 'fal-ai/flux/dev' }
                    @{ prompt = 'Forest path';      model = 'fal-ai/flux/schnell' }
                )

                $results = $jobs | ForEach-Object {
                    Wait-FalJob -Model $_.model -Body @{ prompt = $_.prompt }
                }

                $results.Count | Should -Be 3
                $results | ForEach-Object {
                    $_.images.Count | Should -BeGreaterOrEqual 1
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Queue error handling' {
        It 'Should throw when queue submission fails' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ error = 'Rate limit exceeded' }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                { Wait-FalJob -Model 'fal-ai/flux/dev' -Body @{ prompt = 'rate limited' } } |
                    Should -Throw '*Queue submission failed*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }
}
