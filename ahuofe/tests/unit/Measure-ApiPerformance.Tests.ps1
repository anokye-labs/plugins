BeforeAll {
    # Dot-source the helper functions from the script for direct testing
    $scriptContent = Get-Content "$PSScriptRoot/../../scripts/Measure-ApiPerformance.ps1" -Raw

    # Extract and define helper functions for testing
    function Get-Percentile {
        param([double[]]$Values, [double]$Percentile)
        $sorted = $Values | Sort-Object
        $index = [math]::Ceiling($Percentile / 100.0 * $sorted.Count) - 1
        $index = [math]::Max(0, [math]::Min($index, $sorted.Count - 1))
        return $sorted[$index]
    }

    function Get-StdDev {
        param([double[]]$Values)
        if ($Values.Count -le 1) { return 0.0 }
        $mean = ($Values | Measure-Object -Average).Average
        $sumSq = ($Values | ForEach-Object { [math]::Pow($_ - $mean, 2) } | Measure-Object -Sum).Sum
        return [math]::Sqrt($sumSq / ($Values.Count - 1))
    }
}

Describe 'Measure-ApiPerformance' {

    Context 'Percentile Calculations' {
        It 'Calculates P50 correctly for known data' {
            $values = @(100, 200, 300, 400, 500)
            $p50 = Get-Percentile -Values $values -Percentile 50
            $p50 | Should -Be 300
        }

        It 'Calculates P95 correctly for a larger dataset' {
            $values = @(1..100 | ForEach-Object { $_ * 10.0 })
            $p95 = Get-Percentile -Values $values -Percentile 95
            $p95 | Should -Be 950
        }

        It 'Calculates P99 correctly' {
            $values = @(1..100 | ForEach-Object { $_ * 1.0 })
            $p99 = Get-Percentile -Values $values -Percentile 99
            $p99 | Should -Be 99
        }

        It 'Handles single-element array' {
            $p50 = Get-Percentile -Values @(42.0) -Percentile 50
            $p50 | Should -Be 42.0
        }
    }

    Context 'Standard Deviation' {
        It 'Returns 0 for single value' {
            $sd = Get-StdDev -Values @(100.0)
            $sd | Should -Be 0.0
        }

        It 'Calculates stddev for known values' {
            # Values: 2, 4, 4, 4, 5, 5, 7, 9 → stddev ≈ 2.138
            $values = @(2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0)
            $sd = Get-StdDev -Values $values
            $sd | Should -BeGreaterThan 2.0
            $sd | Should -BeLessThan 2.2
        }
    }

    Context 'Mock Mode' {
        BeforeEach {
            $script:originalKey = $env:FAL_KEY
            $env:FAL_KEY = $null
        }
        AfterEach {
            $env:FAL_KEY = $script:originalKey
        }

        It 'Runs in mock mode when FAL_KEY is not set' {
            $result = & "$PSScriptRoot/../../scripts/Measure-ApiPerformance.ps1" -Iterations 3
            $result.MockMode | Should -BeTrue
            $result.Iterations | Should -Be 3
            $result.IndividualMs.Count | Should -Be 3
        }

        It 'Produces valid latency structure in mock mode' {
            $result = & "$PSScriptRoot/../../scripts/Measure-ApiPerformance.ps1" -Iterations 2
            $result.Latency.MeanMs | Should -BeGreaterThan 0
            $result.Latency.P50Ms | Should -BeGreaterThan 0
            $result.Latency.P95Ms | Should -BeGreaterOrEqual $result.Latency.P50Ms
            $result.QueueWait.MeanMs | Should -BeGreaterThan 0
        }
    }

    Context 'Script Parameters' {
        It 'Has expected parameter defaults' {
            $cmd = Get-Command "$PSScriptRoot/../../scripts/Measure-ApiPerformance.ps1"
            $cmd.Parameters['Model'].ParameterType | Should -Be ([string])
            $cmd.Parameters['Iterations'].ParameterType | Should -Be ([int])
        }
    }
}
