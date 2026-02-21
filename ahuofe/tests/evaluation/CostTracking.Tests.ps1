BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:ScriptPath = Resolve-Path "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1"
}

Describe 'Cost Tracking Evaluation' {
    BeforeAll {
        $script:MockUsage = [PSCustomObject]@{
            TotalCost     = 12.50
            TotalRequests = 100
            StartDate     = '2025-01-01'
            EndDate       = '2025-01-15'
            ByEndpoint    = @(
                [PSCustomObject]@{ EndpointId = 'fal-ai/flux/dev'; Cost = 8.00; Quantity = 60 }
                [PSCustomObject]@{ EndpointId = 'fal-ai/flux/schnell'; Cost = 4.50; Quantity = 40 }
            )
        }
    }

    Context 'When analyzing mock usage data' {
        BeforeAll {
            $script:Result = & $script:ScriptPath -UsageData $script:MockUsage
        }

        It 'Should calculate cost per request' {
            $script:Result.CostPerRequest | Should -BeGreaterThan 0
            $script:Result.CostPerRequest | Should -BeLessOrEqual 1.0
        }

        It 'Should project monthly cost from daily rate' {
            $script:Result.ProjectedMonthly | Should -BeGreaterThan 0
            $script:Result.DailyCost | Should -BeGreaterThan 0
        }

        It 'Should report correct period coverage' {
            $script:Result.Period.DaysCovered | Should -Be 14
        }
    }

    Context 'Budget alert thresholds' {
        It 'Should return OK status when under budget' {
            $result = & $script:ScriptPath -UsageData $script:MockUsage -BudgetLimit 100
            $result.BudgetAlert.Status | Should -Be 'OK'
        }

        It 'Should return EXCEEDED when projected cost exceeds budget' {
            $result = & $script:ScriptPath -UsageData $script:MockUsage -BudgetLimit 1
            $result.BudgetAlert.Status | Should -Be 'EXCEEDED'
            $result.BudgetAlert.Message | Should -Match 'exceeds'
        }
    }

    Context 'Per-model cost breakdown' {
        It 'Should break down costs by model endpoint' {
            $result = & $script:ScriptPath -UsageData $script:MockUsage
            $result.ModelBreakdown.Count | Should -Be 2
            $result.ModelBreakdown[0].EndpointId | Should -Be 'fal-ai/flux/dev'
            $result.ModelBreakdown[0].CostPerRequest | Should -BeGreaterThan 0
        }
    }
}
