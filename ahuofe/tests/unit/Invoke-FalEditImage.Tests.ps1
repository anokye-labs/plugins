BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:inpaintScript = Resolve-Path "$PSScriptRoot/../../scripts/Invoke-FalInpainting.ps1"
}

Describe 'Invoke-FalInpainting' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'test-key'
        Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
    }
    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Sync inpainting' {
        It 'Returns inpainted image with correct output structure' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/inpainted.png'; width = 512; height = 512 })
                    seed   = 55
                }
            } -ModuleName FalAi

            $result = & $script:inpaintScript `
                -ImageUrl 'https://fal.media/input.png' `
                -MaskUrl  'https://fal.media/mask.png' `
                -Prompt   'a blue sky'

            $result | Should -BeOfType 'PSCustomObject'
            $result.Images.Count | Should -Be 1
            $result.Images[0].Url | Should -Be 'https://fal.ai/inpainted.png'
            $result.Seed | Should -Be 55
        }

        It 'Builds correct API payload with all fields' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/inp2.png'; width = 512; height = 512 })
                    seed   = 10
                }
            } -ModuleName FalAi

            & $script:inpaintScript `
                -ImageUrl 'https://fal.media/src.png' `
                -MaskUrl  'https://fal.media/m.png' `
                -Prompt   'red rose' `
                -Strength 0.9 `
                -NumInferenceSteps 25 `
                -GuidanceScale 8.0

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Body -match '"image_url"' -and
                $Body -match '"mask_url"' -and
                $Body -match '"prompt"' -and
                $Body -match '"strength"' -and
                $Body -match '"num_inference_steps"' -and
                $Body -match '"guidance_scale"'
            }
        }
    }

    Context 'Missing parameters' {
        It 'Has ImageUrl marked as mandatory' {
            $cmd = Get-Command $script:inpaintScript
            $attr = $cmd.Parameters['ImageUrl'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }

        It 'Has MaskUrl marked as mandatory' {
            $cmd = Get-Command $script:inpaintScript
            $attr = $cmd.Parameters['MaskUrl'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }

        It 'Has Prompt marked as mandatory' {
            $cmd = Get-Command $script:inpaintScript
            $attr = $cmd.Parameters['Prompt'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }
    }
}
