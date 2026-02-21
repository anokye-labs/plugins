BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:upscaleScript = Resolve-Path "$PSScriptRoot/../../scripts/Invoke-FalUpscale.ps1"
}

Describe 'Invoke-FalUpscale' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'test-key'
        Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
    }
    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Sync upscale' {
        It 'Returns output with Image, Width, Height' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    image = [PSCustomObject]@{ url = 'https://fal.ai/upscaled.png'; width = 2048; height = 2048 }
                }
            } -ModuleName FalAi

            $result = & $script:upscaleScript -ImageUrl 'https://fal.media/input.png'
            $result | Should -BeOfType 'PSCustomObject'
            $result.Image.Url | Should -Be 'https://fal.ai/upscaled.png'
            $result.Width | Should -Be 2048
            $result.Height | Should -Be 2048
        }

        It 'Sends correct endpoint and payload' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    image = [PSCustomObject]@{ url = 'https://fal.ai/up4x.png'; width = 4096; height = 4096 }
                }
            } -ModuleName FalAi

            & $script:upscaleScript -ImageUrl 'https://fal.media/small.png' -Scale 4

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Uri -match 'fal-ai/aura-sr' -and $Body -match '"image_url"' -and $Body -match '"scale":\s*4'
            }
        }
    }

    Context 'Missing parameters' {
        It 'Has ImageUrl marked as mandatory' {
            $cmd = Get-Command $script:upscaleScript
            $attr = $cmd.Parameters['ImageUrl'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }
    }
}
