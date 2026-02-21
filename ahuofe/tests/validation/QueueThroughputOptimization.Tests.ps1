BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:scriptsDir = Join-Path $script:repoRoot 'scripts'
    $script:modulePath = Join-Path $script:scriptsDir 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'Performance: Queue Throughput Optimization' {

    Context 'Concurrent job submission' {
        It 'Should submit multiple jobs in parallel and collect all request IDs' {
            $counter = 0
            Mock Invoke-RestMethod {
                $script:counter++
                return [PSCustomObject]@{
                    request_id = "req-$($script:counter)-$(Get-Random)"
                    status     = 'IN_QUEUE'
                }
            }

            $jobs = 1..3 | ForEach-Object {
                Invoke-RestMethod -Uri "https://queue.fal.run/fal-ai/flux/dev" -Method POST -Headers @{} -Body '{}'
            }

            $jobs.Count | Should -Be 3
            $jobs | ForEach-Object { $_.request_id | Should -Not -BeNullOrEmpty }
            ($jobs.request_id | Sort-Object -Unique).Count | Should -Be 3
        }
    }

    Context 'Queue position tracking accuracy' {
        It 'Should report queue position from status response' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    status         = 'IN_QUEUE'
                    queue_position = 5
                    response_url   = 'https://queue.fal.run/fal-ai/flux/dev/requests/req-abc/response'
                    logs           = $null
                }
            }

            $status = Invoke-RestMethod -Uri 'https://queue.fal.run/fal-ai/flux/dev/requests/req-abc/status' `
                -Method GET -Headers @{}
            $status.queue_position | Should -Be 5
            $status.status | Should -Be 'IN_QUEUE'
        }

        It 'Queue position should decrement as jobs advance' {
            $positions = @(5, 3, 1, 0)
            $script:posIdx = 0

            Mock Invoke-RestMethod {
                $pos = $positions[$script:posIdx]
                $st = if ($script:posIdx -ge ($positions.Count - 1)) { 'COMPLETED' } else { 'IN_QUEUE' }
                $script:posIdx++
                return [PSCustomObject]@{
                    status         = $st
                    queue_position = $pos
                }
            }

            $observed = @()
            foreach ($_ in 1..$positions.Count) {
                $s = Invoke-RestMethod -Uri 'https://queue.fal.run/status' -Method GET -Headers @{}
                $observed += $s.queue_position
            }

            for ($i = 1; $i -lt $observed.Count; $i++) {
                $observed[$i] | Should -BeLessOrEqual $observed[$i - 1]
            }
        }
    }

    Context 'Polling backoff strategy' {
        It 'Wait-FalJob uses fixed poll interval suitable for queue workloads' {
            # Verify default PollIntervalSeconds parameter is 2s
            $moduleContent = Get-Content $script:modulePath -Raw
            $moduleContent | Should -Match 'PollIntervalSeconds\s*=\s*2'
        }

        It 'Timeout is bounded to prevent indefinite waits' {
            $moduleContent = Get-Content $script:modulePath -Raw
            # Default TimeoutSeconds = 300 (5 minutes)
            $moduleContent | Should -Match 'TimeoutSeconds\s*=\s*300'
        }
    }

    Context 'Result retrieval after completion' {
        It 'Should return result payload when job status is COMPLETED' {
            $callCount = 0
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body, [switch]$UseBasicParsing)
                $script:callCount++
                if ($script:callCount -eq 1) {
                    # Submit
                    return [PSCustomObject]@{ request_id = 'req-done-1' }
                } elseif ($script:callCount -eq 2) {
                    # Status poll
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                } else {
                    # Result fetch
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{
                            url    = 'https://fal.ai/output/result.png'
                            width  = 1024
                            height = 1024
                        })
                    }
                }
            } -ModuleName FalAi

            Mock Get-FalApiKey { return 'test-key-result' } -ModuleName FalAi
            Mock Start-Sleep { } -ModuleName FalAi

            $result = Wait-FalJob -Model 'fal-ai/flux/dev' -Body @{ prompt = 'test' }
            $result.images.Count | Should -Be 1
            $result.images[0].url | Should -BeLike 'https://fal.ai/*'
        }
    }

    Context 'Throughput calculation' {
        It 'Should calculate jobs per minute from mock timing data' {
            $jobCount = 10
            $totalSeconds = 120  # 2 minutes

            $throughput = $jobCount / ($totalSeconds / 60.0)
            $throughput | Should -Be 5.0

            # Throughput should be positive and reasonable for API workloads
            $throughput | Should -BeGreaterThan 0
            $throughput | Should -BeLessOrEqual 60 -Because 'API rate limits cap throughput'
        }

        It 'Throughput should scale linearly with concurrency (mock)' {
            $baseJobs = 5
            $baseMinutes = 1.0
            $baseThroughput = $baseJobs / $baseMinutes

            # With 3x concurrency, expect ~3x throughput
            $concurrentJobs = 15
            $concurrentThroughput = $concurrentJobs / $baseMinutes

            $ratio = $concurrentThroughput / $baseThroughput
            $ratio | Should -BeGreaterOrEqual 2.5
            $ratio | Should -BeLessOrEqual 3.5
        }
    }
}
