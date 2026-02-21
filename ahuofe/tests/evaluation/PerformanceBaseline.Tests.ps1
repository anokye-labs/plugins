BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:ScriptPath = Resolve-Path "$PSScriptRoot/../../scripts/Measure-ApiPerformance.ps1"
}

Describe 'Performance Baseline Evaluation' {
    Context 'When calculating latency percentiles with mock data' {
        BeforeAll {
            # Run with 5 iterations in mock mode (no FAL_KEY)
            $savedKey = $env:FAL_KEY
            $env:FAL_KEY = $null
            $script:Result = & $script:ScriptPath -Iterations 5
            $env:FAL_KEY = $savedKey
        }

        It 'Should run in mock mode without FAL_KEY' {
            $script:Result.MockMode | Should -BeTrue
        }

        It 'Should calculate P50 latency' {
            $script:Result.Latency.P50Ms | Should -BeGreaterThan 0
        }

        It 'Should calculate P95 latency greater than or equal to P50' {
            $script:Result.Latency.P95Ms | Should -BeGreaterOrEqual $script:Result.Latency.P50Ms
        }

        It 'Should calculate P99 latency greater than or equal to P95' {
            $script:Result.Latency.P99Ms | Should -BeGreaterOrEqual $script:Result.Latency.P95Ms
        }

        It 'Should report mean and standard deviation' {
            $script:Result.Latency.MeanMs | Should -BeGreaterThan 0
            $script:Result.Latency.StdDevMs | Should -BeOfType [double]
        }
    }

    Context 'Threshold alerting' {
        BeforeAll {
            $savedKey = $env:FAL_KEY
            $env:FAL_KEY = $null
            $script:ThresholdResult = & $script:ScriptPath -Iterations 3
            $env:FAL_KEY = $savedKey

            $thresholds = Get-Content (Join-Path $PSScriptRoot '../fixtures/quality-thresholds.json') -Raw | ConvertFrom-Json
            $script:MaxGenTime = $thresholds.performance.max_generation_time_seconds * 1000
        }

        It 'Should have individual timings matching iteration count' {
            $script:ThresholdResult.IndividualMs.Count | Should -Be 3
        }

        It 'Should produce queue wait metrics' {
            $script:ThresholdResult.QueueWait.MeanMs | Should -BeGreaterThan 0
            $script:ThresholdResult.QueueWait.P50Ms | Should -BeGreaterThan 0
        }
    }
}
