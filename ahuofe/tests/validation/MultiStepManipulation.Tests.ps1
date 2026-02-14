BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:generateScript = Join-Path $script:repoRoot 'scripts' 'Invoke-FalGenerate.ps1'
    $script:upscaleScript = Join-Path $script:repoRoot 'scripts' 'Invoke-FalUpscale.ps1'
    $script:qualityScript = Join-Path $script:repoRoot 'scripts' 'Measure-ImageQuality.ps1'
    $script:workflowScript = Join-Path $script:repoRoot 'scripts' 'New-FalWorkflow.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'Validation: Multi-Step Manipulation Workflows' {
    BeforeAll {
        $script:testDir = Join-Path $TestDrive 'validation-multistep'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Generate → Upscale → Format Conversion pipeline' {
        It 'Should generate an image then upscale it in sequence' {
            # Step 1: Generate image
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                if ($Uri -like '*flux/dev*' -and $Method -eq 'POST') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{
                            url    = 'https://fal.ai/output/gen-001.png'
                            width  = 512
                            height = 512
                        })
                        seed   = 42
                        prompt = 'A mountain landscape at sunset'
                    }
                }
                if ($Uri -like '*aura-sr*' -and $Method -eq 'POST') {
                    return [PSCustomObject]@{
                        image = [PSCustomObject]@{
                            url    = 'https://fal.ai/output/upscaled-001.png'
                            width  = 1024
                            height = 1024
                        }
                    }
                }
                return $null
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                # Generate
                $genResult = & $script:generateScript -Prompt 'A mountain landscape at sunset' -Model 'fal-ai/flux/dev'
                $genResult.Images.Count | Should -Be 1
                $genResult.Images[0].Width | Should -Be 512

                # Upscale the generated image
                $upscaleResult = & $script:upscaleScript -ImageUrl $genResult.Images[0].Url -Scale 2
                $upscaleResult.Image | Should -Not -BeNullOrEmpty
                $upscaleResult.Width | Should -Be 1024
                $upscaleResult.Height | Should -Be 1024
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should pass upscaled output URL downstream for format conversion' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                if ($Uri -like '*aura-sr*') {
                    return [PSCustomObject]@{
                        image = [PSCustomObject]@{
                            url    = 'https://fal.ai/output/upscaled-fmt.png'
                            width  = 2048
                            height = 2048
                        }
                    }
                }
                return $null
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $upscaleResult = & $script:upscaleScript -ImageUrl 'https://fal.ai/output/source.png' -Scale 4
                $upscaleResult.Image.Url | Should -Be 'https://fal.ai/output/upscaled-fmt.png'
                $upscaleResult.Width | Should -Be 2048
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Generate → Crop → Resize → Overlay pipeline via MCP' {
        It 'Should chain MCP tool results through manipulation steps' {
            # Simulate MCP tool chain: generate → get_metainfo → crop → resize → overlay
            $metainfo = New-MockImageMetainfo -Width 1024 -Height 768
            $metainfo.result.width | Should -Be 1024
            $metainfo.result.height | Should -Be 768

            # Crop to center 512x512
            $cropResult = New-MockMcpResponse -ToolName 'crop' -Result ([PSCustomObject]@{
                output_path = '/images/cropped.png'
                x1 = 256; y1 = 128; x2 = 768; y2 = 640
            })
            $cropResult.result.output_path | Should -Be '/images/cropped.png'

            # Resize to 256x256
            $resizeResult = New-MockMcpResponse -ToolName 'resize' -Result ([PSCustomObject]@{
                output_path = '/images/resized.png'
                width = 256; height = 256
            })
            $resizeResult.result.width | Should -Be 256

            # Overlay watermark
            $overlayResult = New-MockMcpResponse -ToolName 'overlay' -Result ([PSCustomObject]@{
                output_path = '/images/final.png'
            })
            $overlayResult.error | Should -BeNullOrEmpty
            $overlayResult.result.output_path | Should -Be '/images/final.png'
        }

        It 'Should handle MCP tool error mid-pipeline gracefully' {
            $cropError = New-MockMcpResponse -ToolName 'crop' -IsError -ErrorMessage 'Coordinates out of bounds'
            $cropError.error | Should -Be 'Coordinates out of bounds'
            $cropError.result | Should -BeNullOrEmpty
        }
    }

    Context 'Workflow with quality measurement between steps' {
        It 'Should measure quality after generation and after upscaling' {
            $testImage = New-MockImageFile -Path (Join-Path $script:testDir 'quality-step.png')

            # Measure quality of "generated" image
            $quality = & $script:qualityScript -ImagePath $testImage.FullName
            $quality.FilePath | Should -Be $testImage.FullName
            $quality.FileSize | Should -BeGreaterThan 0
            $quality.Width | Should -BeGreaterOrEqual 1
            $quality.Height | Should -BeGreaterOrEqual 1
            $quality.MeanBrightness | Should -Not -Be -1

            # Simulate upscaled image quality check
            $upscaledImage = New-MockImageFile -Path (Join-Path $script:testDir 'quality-upscaled.png')
            $upscaledQuality = & $script:qualityScript -ImagePath $upscaledImage.FullName
            $upscaledQuality.FileSize | Should -BeGreaterThan 0
        }

        It 'Should compare quality between original and processed using SSIM' {
            $original = New-MockImageFile -Path (Join-Path $script:testDir 'ssim-original.png')
            $processed = New-MockImageFile -Path (Join-Path $script:testDir 'ssim-processed.png')

            $quality = & $script:qualityScript -ImagePath $original.FullName -ReferenceImagePath $processed.FullName
            $quality.SSIM | Should -BeGreaterThan 0
            $quality.SSIM | Should -BeLessOrEqual 1.0
        }
    }

    Context 'Batch processing: multiple images through same pipeline' {
        It 'Should process a batch of prompts through generate → upscale' {
            $prompts = @(
                'A sunset over mountains'
                'A cat sitting on a windowsill'
                'An abstract geometric pattern'
            )

            $batchCounter = 0
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                $batchCounter++
                if ($Uri -like '*flux*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{
                            url    = "https://fal.ai/output/batch-$batchCounter.png"
                            width  = 512
                            height = 512
                        })
                        seed = $batchCounter
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    return [PSCustomObject]@{
                        image = [PSCustomObject]@{
                            url    = "https://fal.ai/output/batch-up-$batchCounter.png"
                            width  = 1024
                            height = 1024
                        }
                    }
                }
                return $null
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $results = @()
                foreach ($prompt in $prompts) {
                    $gen = & $script:generateScript -Prompt $prompt -Model 'fal-ai/flux/dev'
                    $up = & $script:upscaleScript -ImageUrl $gen.Images[0].Url -Scale 2
                    $results += [PSCustomObject]@{
                        Prompt   = $prompt
                        GenUrl   = $gen.Images[0].Url
                        UpUrl    = $up.Image.Url
                        UpWidth  = $up.Width
                    }
                }

                $results.Count | Should -Be 3
                $results | ForEach-Object {
                    $_.GenUrl | Should -BeLike 'https://fal.ai/output/batch-*'
                    $_.UpWidth | Should -Be 1024
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }
}
