BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:scriptPath = Join-Path $script:repoRoot 'scripts' 'Invoke-FalGenerate.ps1'
    $script:qualityScript = Join-Path $script:repoRoot 'scripts' 'Measure-ImageQuality.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force

    # Load golden prompts and quality thresholds
    $script:goldenPrompts = (Get-Content (Get-TestFixturePath 'golden-prompts.json') -Raw | ConvertFrom-Json).prompts
    $script:qualityThresholds = Get-Content (Get-TestFixturePath 'quality-thresholds.json') -Raw | ConvertFrom-Json
}

Describe 'Validation: Text-to-Image Workflow' {
    BeforeAll {
        $script:testDir = Join-Path $TestDrive 'validation-t2i'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Golden prompt generation with flux/dev' {
        It 'Should generate image from photorealistic golden prompt' {
            $prompt = $script:goldenPrompts | Where-Object { $_.id -eq 'img-001' }

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = 'https://fal.ai/output/golden-001.png'
                        width  = 1024
                        height = 1024
                    })
                    seed   = 12345
                    prompt = 'A professional headshot of a person in business attire, studio lighting, neutral background'
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt $prompt.prompt -Model $prompt.model
                $result.Images.Count | Should -Be 1
                $result.Images[0].Width | Should -Be $prompt.expected_dimensions.width
                $result.Images[0].Height | Should -Be $prompt.expected_dimensions.height
                $result.Model | Should -Be $prompt.model
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should generate image from artistic golden prompt' {
            $prompt = $script:goldenPrompts | Where-Object { $_.id -eq 'img-004' }

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = 'https://fal.ai/output/golden-004.png'
                        width  = 1024
                        height = 1024
                    })
                    seed   = 7890
                    prompt = 'An oil painting of a coastal village at sunset, impressionist style, warm colors'
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt $prompt.prompt -Model $prompt.model
                $result.Images.Count | Should -Be 1
                $result.Prompt | Should -Be $prompt.prompt
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should generate image from product photography golden prompt' {
            $prompt = $script:goldenPrompts | Where-Object { $_.id -eq 'img-007' }

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = 'https://fal.ai/output/golden-007.png'
                        width  = 1024
                        height = 1024
                    })
                    seed   = 555
                    prompt = 'A pair of wireless headphones on a white marble surface, product photography, soft shadows'
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt $prompt.prompt -Model $prompt.model
                $result.Images[0].Url | Should -BeLike 'https://fal.ai/*'
                $result.Images[0].Width | Should -Be 1024
                $result.Images[0].Height | Should -Be 1024
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Model variant generation' {
        It 'Should generate with flux/schnell model from golden prompt' {
            $prompt = $script:goldenPrompts | Where-Object { $_.id -eq 'img-021' }

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = 'https://fal.ai/output/schnell-021.png'
                        width  = 1024
                        height = 1024
                    })
                    seed   = 42
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt $prompt.prompt -Model 'fal-ai/flux/schnell'
                $result.Model | Should -Be 'fal-ai/flux/schnell'
                $result.Images.Count | Should -Be 1
                Should -Invoke Invoke-RestMethod -ModuleName FalAi -ParameterFilter {
                    $Uri -like '*flux/schnell*'
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should handle landscape golden prompts with correct aspect ratio' {
            $prompt = $script:goldenPrompts | Where-Object { $_.id -eq 'img-010' }

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = 'https://fal.ai/output/landscape-010.png'
                        width  = 1024
                        height = 576
                    })
                    seed   = 99
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt $prompt.prompt -ImageSize 'landscape_16_9'
                $result.Images[0].Width | Should -Be 1024
                $result.Images[0].Height | Should -Be 576
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Image size and parameter variations' {
        It 'Should generate portrait-oriented image with custom dimensions' {
            $prompt = $script:goldenPrompts | Where-Object { $_.id -eq 'img-006' }

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = 'https://fal.ai/output/portrait-006.png'
                        width  = 768
                        height = 1024
                    })
                    seed   = 77
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt $prompt.prompt -ImageSize 'portrait_3_4'
                $result.Images[0].Width | Should -Be 768
                $result.Images[0].Height | Should -Be 1024
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should pass guidance scale and inference steps for detailed art' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url = 'https://fal.ai/output/detailed.png'
                        width = 1024; height = 1024
                    })
                    seed = 1
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                & $script:scriptPath -Prompt 'Abstract geometric patterns' `
                    -GuidanceScale 7.5 -NumInferenceSteps 30 | Out-Null
                Should -Invoke Invoke-RestMethod -ModuleName FalAi -ParameterFilter {
                    $parsed = $Body | ConvertFrom-Json
                    $parsed.guidance_scale -eq 7.5 -and $parsed.num_inference_steps -eq 30
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Quality measurement integration' {
        It 'Should measure quality metrics for generated image' {
            $testImage = New-MockImageFile -Path (Join-Path $script:testDir 'quality-test.png')

            $quality = & $script:qualityScript -ImagePath $testImage.FullName
            $quality.FilePath | Should -Be $testImage.FullName
            $quality.FileSize | Should -BeGreaterThan 0
            $quality.Width | Should -BeGreaterOrEqual 1
            $quality.Height | Should -BeGreaterOrEqual 1
            $quality.MeanBrightness | Should -Not -Be -1
        }

        It 'Should validate quality thresholds from fixture config' {
            $thresholds = $script:qualityThresholds.image
            $thresholds.min_file_size_bytes | Should -BeGreaterThan 0
            $thresholds.min_brightness | Should -BeGreaterOrEqual 0
            $thresholds.max_brightness | Should -BeLessOrEqual 1
            $thresholds.min_contrast | Should -BeGreaterOrEqual 0
            $thresholds.ssim_threshold | Should -BeGreaterThan 0
        }
    }

    Context 'Complete workflow: load prompt, generate, validate' {
        It 'Should execute full workflow from golden prompt to validated output' {
            # Step 1: Load a golden prompt
            $prompt = $script:goldenPrompts | Where-Object { $_.id -eq 'img-002' }
            $prompt | Should -Not -BeNullOrEmpty
            $prompt.category | Should -Be 'photorealistic'

            # Step 2: Mock generation
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = 'https://fal.ai/output/workflow-002.png'
                        width  = 1024
                        height = 768
                    })
                    seed   = 42
                    prompt = 'A golden retriever sitting in a sunlit park, shallow depth of field, bokeh background'
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:scriptPath -Prompt $prompt.prompt -Model $prompt.model
                $result.Images.Count | Should -Be 1
                $result.Images[0].Width | Should -Be $prompt.expected_dimensions.width
                $result.Images[0].Height | Should -Be $prompt.expected_dimensions.height
                $result.Model | Should -Be $prompt.model

                # Step 3: Validate output structure
                $result.PSObject.Properties.Name | Should -Contain 'Images'
                $result.PSObject.Properties.Name | Should -Contain 'Seed'
                $result.PSObject.Properties.Name | Should -Contain 'Model'

                # Step 4: Validate against golden prompt thresholds
                $result.Images[0].Url | Should -BeLike 'https://fal.ai/*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }
}
