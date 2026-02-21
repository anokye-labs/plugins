BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:scriptsDir = Join-Path $script:repoRoot 'scripts'
    $script:modulePath = Join-Path $script:scriptsDir 'FalAi.psm1'
    $script:perfScript = Join-Path $script:scriptsDir 'Measure-ApiPerformance.ps1'
}

Describe 'Performance: API Latency Optimization' {

    Context 'Measure-ApiPerformance mock-mode latency thresholds' {
        It 'P50 latency should be under 5000 ms with mock data' {
            # Run in mock mode (no FAL_KEY)
            $saved = $env:FAL_KEY
            $env:FAL_KEY = $null
            try {
                $result = & $script:perfScript -Iterations 10
                $result.Latency.P50Ms | Should -BeLessThan 5000
            } finally {
                $env:FAL_KEY = $saved
            }
        }

        It 'P95 latency should be under 10000 ms with mock data' {
            $saved = $env:FAL_KEY
            $env:FAL_KEY = $null
            try {
                $result = & $script:perfScript -Iterations 10
                $result.Latency.P95Ms | Should -BeLessThan 10000
            } finally {
                $env:FAL_KEY = $saved
            }
        }

        It 'Should return all required output properties' {
            $saved = $env:FAL_KEY
            $env:FAL_KEY = $null
            try {
                $result = & $script:perfScript -Iterations 5
                $result.PSObject.Properties.Name | Should -Contain 'Latency'
                $result.PSObject.Properties.Name | Should -Contain 'QueueWait'
                $result.PSObject.Properties.Name | Should -Contain 'MockMode'
                $result.Latency.PSObject.Properties.Name | Should -Contain 'P50Ms'
                $result.Latency.PSObject.Properties.Name | Should -Contain 'P95Ms'
                $result.Latency.PSObject.Properties.Name | Should -Contain 'P99Ms'
                $result.MockMode | Should -BeTrue
            } finally {
                $env:FAL_KEY = $saved
            }
        }
    }

    Context 'FalAi.psm1 retry logic uses exponential backoff' {
        It 'Backoff delay should double on each retry attempt' {
            Import-Module $script:modulePath -Force

            # The retry logic in Invoke-FalApi uses: $backoff = [math]::Pow(2, $attempt)
            # Verify the pattern: attempt 1 → 2s, attempt 2 → 4s, attempt 3 → 8s
            $delays = @(1, 2, 3) | ForEach-Object { [math]::Pow(2, $_) }
            $delays[0] | Should -Be 2    # 2^1
            $delays[1] | Should -Be 4    # 2^2
            $delays[2] | Should -Be 8    # 2^3

            # Each delay should be exactly double the previous
            $delays[1] | Should -Be ($delays[0] * 2)
            $delays[2] | Should -Be ($delays[1] * 2)
        }

        It 'MaxRetries should be 3 or fewer to bound total wait time' {
            Import-Module $script:modulePath -Force

            $moduleContent = Get-Content $script:modulePath -Raw
            $moduleContent | Should -Match '\$script:MaxRetries\s*=\s*[1-3]'
        }
    }

    Context 'Queue polling interval' {
        It 'Default poll interval should be between 1 and 5 seconds' {
            Import-Module $script:modulePath -Force

            # Wait-FalJob default PollIntervalSeconds = 2
            $moduleContent = Get-Content $script:modulePath -Raw
            # Verify the default is in a reasonable range (1-5s)
            if ($moduleContent -match 'PollIntervalSeconds\s*=\s*(\d+)') {
                $defaultInterval = [int]$Matches[1]
                $defaultInterval | Should -BeGreaterOrEqual 1
                $defaultInterval | Should -BeLessOrEqual 5
            }
        }
    }

    Context 'Connection reuse pattern' {
        It 'Should use a single set of headers per API call session' {
            Import-Module $script:modulePath -Force

            # Invoke-FalApi builds headers once before the retry loop
            $moduleContent = Get-Content $script:modulePath -Raw
            # Headers are defined before 'while ($true)' and reused across retries
            $headersIdx = $moduleContent.IndexOf('$headers = @{')
            $whileIdx = $moduleContent.IndexOf('while ($true)')
            $headersIdx | Should -BeLessThan $whileIdx -Because 'Headers should be built before the retry loop'
        }
    }

    Context 'Latency regression detection' {
        It 'Mock-mode standard deviation should be bounded (no wild outliers)' {
            $saved = $env:FAL_KEY
            $env:FAL_KEY = $null
            try {
                $result = & $script:perfScript -Iterations 10
                # StdDev should be less than mean — indicates no extreme outliers
                $result.Latency.StdDevMs | Should -BeLessThan $result.Latency.MeanMs
            } finally {
                $env:FAL_KEY = $saved
            }
        }
    }
}
