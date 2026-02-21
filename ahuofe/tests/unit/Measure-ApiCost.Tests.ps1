BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
}

Describe 'Measure-ApiCost' {

    Context 'Cost Calculations' {
        It 'Calculates per-request cost correctly' {
            $usage = [PSCustomObject]@{
                StartDate     = '2025-01-01'
                EndDate       = '2025-01-31'
                TotalCost     = 15.00
                TotalRequests = 100
                ByEndpoint    = @(
                    [PSCustomObject]@{ EndpointId = 'fal-ai/flux/dev'; Cost = 10.00; Quantity = 80 }
                    [PSCustomObject]@{ EndpointId = 'fal-ai/flux/schnell'; Cost = 5.00; Quantity = 20 }
                )
            }
            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -UsageData $usage
            $result.CostPerRequest | Should -Be 0.15
            $result.TotalCost | Should -Be 15.0
            $result.TotalRequests | Should -Be 100
        }

        It 'Projects monthly cost from shorter periods' {
            $usage = [PSCustomObject]@{
                StartDate     = '2025-01-01'
                EndDate       = '2025-01-08'
                TotalCost     = 7.00
                TotalRequests = 50
                ByEndpoint    = @()
            }
            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -UsageData $usage
            $result.ProjectedMonthly | Should -Be 30.0
            $result.DailyCost | Should -BeGreaterThan 0
        }

        It 'Handles zero requests gracefully' {
            $usage = [PSCustomObject]@{
                StartDate     = '2025-01-01'
                EndDate       = '2025-01-31'
                TotalCost     = 0
                TotalRequests = 0
                ByEndpoint    = @()
            }
            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -UsageData $usage
            $result.CostPerRequest | Should -Be 0
            $result.ProjectedMonthly | Should -Be 0
        }
    }

    Context 'Budget Alert Logic' {
        It 'Returns OK when under budget' {
            $usage = [PSCustomObject]@{
                StartDate     = '2025-01-01'
                EndDate       = '2025-01-31'
                TotalCost     = 10.00
                TotalRequests = 50
                ByEndpoint    = @()
            }
            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -UsageData $usage -BudgetLimit 100
            $result.BudgetAlert.Status | Should -Be 'OK'
            $result.BudgetAlert.Message | Should -BeNullOrEmpty
        }

        It 'Returns EXCEEDED when projected cost exceeds budget' {
            $usage = [PSCustomObject]@{
                StartDate     = '2025-01-01'
                EndDate       = '2025-01-08'
                TotalCost     = 70.00
                TotalRequests = 200
                ByEndpoint    = @()
            }
            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -UsageData $usage -BudgetLimit 50 3>&1 |
                Where-Object { $_ -is [PSCustomObject] }
            $result.BudgetAlert.Status | Should -Be 'EXCEEDED'
            $result.BudgetAlert.Message | Should -Match 'exceeds budget'
        }

        It 'Returns WARNING when projected cost is above 80% of budget' {
            # 10-day period with $27 cost → daily $2.7 → monthly $81 → 81% of $100
            $usage = [PSCustomObject]@{
                StartDate     = '2025-01-01'
                EndDate       = '2025-01-11'
                TotalCost     = 27.00
                TotalRequests = 100
                ByEndpoint    = @()
            }
            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -UsageData $usage -BudgetLimit 100 3>&1 |
                Where-Object { $_ -is [PSCustomObject] }
            $result.BudgetAlert.Status | Should -Be 'WARNING'
            $result.BudgetAlert.Message | Should -Match '80%'
        }
    }

    Context 'Pre-Execution Estimation' {
        BeforeEach {
            $script:savedKey = $env:FAL_KEY
            $env:FAL_KEY = 'mock-key-for-testing'
            Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
        }

        AfterEach {
            $env:FAL_KEY = $script:savedKey
        }

        It 'Estimates cost using live pricing' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ model_id = 'fal-ai/flux/dev'; price = 0.005; unit = 'request'; category = 'image' }
                )
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -ModelId 'fal-ai/flux/dev' -Quantity 100
            $result.ModelId       | Should -Be 'fal-ai/flux/dev'
            $result.Quantity      | Should -Be 100
            $result.PricePerUnit  | Should -Be 0.005
            $result.EstimatedCost | Should -Be 0.5
        }

        It 'Returns zero cost when no pricing found' {
            Mock Invoke-RestMethod {
                return @()
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -ModelId 'fal-ai/unknown' -Quantity 50 3>&1 |
                Where-Object { $_ -is [PSCustomObject] }
            $result.EstimatedCost | Should -Be 0
            $result.PricePerUnit  | Should -Be 0
        }

        It 'Uses provided Unit override' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ model_id = 'fal-ai/flux/dev'; price = 0.0001; unit = 'megapixel'; category = 'image' }
                )
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -ModelId 'fal-ai/flux/dev' -Quantity 10 -Unit 'image'
            $result.Unit | Should -Be 'image'
        }
    }

    Context 'Model Breakdown' {
        It 'Produces per-model cost breakdown' {
            $usage = [PSCustomObject]@{
                StartDate     = '2025-01-01'
                EndDate       = '2025-01-31'
                TotalCost     = 25.00
                TotalRequests = 150
                ByEndpoint    = @(
                    [PSCustomObject]@{ EndpointId = 'fal-ai/flux/dev'; Cost = 20.00; Quantity = 100 }
                    [PSCustomObject]@{ EndpointId = 'fal-ai/flux/schnell'; Cost = 5.00; Quantity = 50 }
                )
            }
            $result = & "$PSScriptRoot/../../scripts/Measure-ApiCost.ps1" -UsageData $usage
            $result.ModelBreakdown.Count | Should -Be 2
            $result.ModelBreakdown[0].CostPerRequest | Should -Be 0.2
            $result.ModelBreakdown[1].CostPerRequest | Should -Be 0.1
        }
    }
}
