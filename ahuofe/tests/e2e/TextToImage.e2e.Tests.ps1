BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:scriptPath = Join-Path $script:repoRoot 'scripts' 'Invoke-FalGenerate.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'E2E: Text-to-Image Generation' {
    BeforeAll {
        $script:testDir = Join-Path $TestDrive 'text-to-image'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    BeforeEach {
        # Prevent scripts from reimporting FalAi with -Force (which clears mocks)
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Basic generation with flux/dev' {
        It 'Should generate an image from a text prompt' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @(
                        [PSCustomObject]@{
                            url    = 'https://fal.ai/output/generated-001.png'
                            width  = 1024
                            height = 768
                        }
                    )
                    seed   = 42
                    prompt = 'A serene mountain landscape'
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt 'A serene mountain landscape'
                $result.Images.Count | Should -Be 1
                $result.Images[0].Url | Should -Be 'https://fal.ai/output/generated-001.png'
                $result.Images[0].Width | Should -Be 1024
                $result.Images[0].Height | Should -Be 768
                $result.Seed | Should -Be 42
                $result.Model | Should -Be 'fal-ai/flux/dev'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should pass prompt text through to the API' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/test.png'; width = 1024; height = 1024 })
                    seed   = 1
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                & $script:scriptPath -Prompt 'A golden retriever in a park' | Out-Null
                Should -Invoke Invoke-RestMethod -ModuleName FalAi -ParameterFilter {
                    ($Body | ConvertFrom-Json).prompt -eq 'A golden retriever in a park'
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Model selection' {
        It 'Should generate with flux/schnell model' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/schnell.png'; width = 1024; height = 1024 })
                    seed   = 99
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt 'A coffee cup' -Model 'fal-ai/flux/schnell'
                $result.Model | Should -Be 'fal-ai/flux/schnell'
                $result.Images.Count | Should -Be 1
                Should -Invoke Invoke-RestMethod -ModuleName FalAi -ParameterFilter {
                    $Uri -like '*flux/schnell*'
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should default to flux/dev when no model specified' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/dev.png'; width = 1024; height = 1024 })
                    seed   = 1
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt 'A landscape'
                $result.Model | Should -Be 'fal-ai/flux/dev'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Parameter variations' {
        It 'Should pass seed parameter for reproducibility' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/seeded.png'; width = 1024; height = 1024 })
                    seed   = 12345
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt 'A cat' -Seed 12345
                $result.Seed | Should -Be 12345
                Should -Invoke Invoke-RestMethod -ModuleName FalAi -ParameterFilter {
                    ($Body | ConvertFrom-Json).seed -eq 12345
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should pass image size parameter' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/wide.png'; width = 1024; height = 576 })
                    seed   = 1
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                & $script:scriptPath -Prompt 'Panorama' -ImageSize 'landscape_16_9' | Out-Null
                Should -Invoke Invoke-RestMethod -ModuleName FalAi -ParameterFilter {
                    ($Body | ConvertFrom-Json).image_size -eq 'landscape_16_9'
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should pass guidance scale and inference steps' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/tuned.png'; width = 1024; height = 1024 })
                    seed   = 1
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                & $script:scriptPath -Prompt 'Detailed art' -GuidanceScale 7.5 -NumInferenceSteps 30 | Out-Null
                Should -Invoke Invoke-RestMethod -ModuleName FalAi -ParameterFilter {
                    $parsed = $Body | ConvertFrom-Json
                    $parsed.guidance_scale -eq 7.5 -and $parsed.num_inference_steps -eq 30
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Output structure validation' {
        It 'Should return structured output with all expected fields' {
            Mock Invoke-RestMethod {
                return New-MockFalApiResponse -Prompt 'test' -Width 512 -Height 512 -Seed 77
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt 'test'
                $result.PSObject.Properties.Name | Should -Contain 'Images'
                $result.PSObject.Properties.Name | Should -Contain 'Seed'
                $result.PSObject.Properties.Name | Should -Contain 'Prompt'
                $result.PSObject.Properties.Name | Should -Contain 'Model'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should handle multiple image generation' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @(
                        [PSCustomObject]@{ url = 'https://fal.ai/output/img1.png'; width = 1024; height = 1024 }
                        [PSCustomObject]@{ url = 'https://fal.ai/output/img2.png'; width = 1024; height = 1024 }
                    )
                    seed = 1
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt 'Variations' -NumImages 2
                $result.Images.Count | Should -Be 2
                $result.Images[0].Url | Should -Not -Be $result.Images[1].Url
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Error handling' {
        It 'Should throw when FAL_KEY is not set' {
            $savedKey = $env:FAL_KEY
            Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue
            try {
                { & $script:scriptPath -Prompt 'test' } | Should -Throw '*FAL_KEY*'
            }
            finally {
                if ($savedKey) { $env:FAL_KEY = $savedKey }
            }
        }

        It 'Should throw on API error response' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('The remote server returned an error: (401) Unauthorized.')
            } -ModuleName FalAi

            $env:FAL_KEY = 'invalid-key'
            try {
                { & $script:scriptPath -Prompt 'test' } | Should -Throw
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }
}
