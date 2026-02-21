BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
}

Describe 'Get-FalPricing' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'mock-key-for-testing'
        Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
    }

    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Returns all pricing when no filters applied' {
        It 'Returns structured pricing objects' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ model_id = 'fal-ai/flux/dev';    price = 0.005; unit = 'request'; category = 'image' }
                    [PSCustomObject]@{ model_id = 'fal-ai/flux/schnell'; price = 0.001; unit = 'request'; category = 'image' }
                )
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalPricing.ps1"
            $result.Count             | Should -Be 2
            $result[0].ModelId        | Should -Be 'fal-ai/flux/dev'
            $result[0].Price          | Should -Be 0.005
            $result[0].Unit           | Should -Be 'request'
            $result[0].PriceFormatted | Should -Match '\$'
        }
    }

    Context 'Filters by ModelId' {
        It 'Returns only matching model' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ model_id = 'fal-ai/flux/dev';    price = 0.005; unit = 'request'; category = 'image' }
                    [PSCustomObject]@{ model_id = 'fal-ai/flux/schnell'; price = 0.001; unit = 'request'; category = 'image' }
                )
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalPricing.ps1" -ModelId 'fal-ai/flux/dev'
            $result.Count      | Should -Be 1
            $result[0].ModelId | Should -Be 'fal-ai/flux/dev'
        }

        It 'Returns empty array when model not found' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ model_id = 'fal-ai/flux/dev'; price = 0.005; unit = 'request'; category = 'image' }
                )
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalPricing.ps1" -ModelId 'fal-ai/nonexistent'
            $result.Count | Should -Be 0
        }
    }

    Context 'Filters by Category' {
        It 'Returns only matching category (case-insensitive)' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ model_id = 'fal-ai/flux/dev'; price = 0.005; unit = 'request'; category = 'image' }
                    [PSCustomObject]@{ model_id = 'fal-ai/veo3.1';   price = 0.10;  unit = 'second';  category = 'video' }
                )
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalPricing.ps1" -Category 'video'
            $result.Count      | Should -Be 1
            $result[0].ModelId | Should -Be 'fal-ai/veo3.1'
        }
    }

    Context 'Handles alternate API response shapes' {
        It 'Unwraps .models property' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    models = @(
                        [PSCustomObject]@{ model_id = 'fal-ai/flux/dev'; price = 0.005; unit = 'request'; category = 'image' }
                    )
                }
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalPricing.ps1"
            $result.Count | Should -Be 1
        }

        It 'Formats price correctly' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ model_id = 'fal-ai/flux/dev'; price = 0.000125; unit = 'megapixel'; category = 'image' }
                )
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalPricing.ps1"
            $result[0].PriceFormatted | Should -Be '$0.000125 per megapixel'
        }
    }
}
