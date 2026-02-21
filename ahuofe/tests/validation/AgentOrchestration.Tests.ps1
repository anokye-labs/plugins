BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:generateScript = Join-Path $script:repoRoot 'scripts' 'Invoke-FalGenerate.ps1'
    $script:workflowScript = Join-Path $script:repoRoot 'scripts' 'New-FalWorkflow.ps1'
    $script:qualityScript = Join-Path $script:repoRoot 'scripts' 'Measure-ImageQuality.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'Validation: Agent Orchestration Patterns' {
    BeforeAll {
        $script:testDir = Join-Path $TestDrive 'validation-orchestration'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Fleet pattern: dispatch 3 generators in parallel' {
        It 'Should dispatch multiple generation requests and collect all results' {
            $global:fleetCallIdx = 0
            Mock Invoke-RestMethod {
                $global:fleetCallIdx++
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = "https://fal.ai/output/fleet-$($global:fleetCallIdx).png"
                        width  = 1024
                        height = 1024
                    })
                    seed = $global:fleetCallIdx * 100
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $prompts = @(
                    'A serene lake at dawn'
                    'A bustling city street at night'
                    'A dense forest in autumn'
                )

                $jobs = @()
                foreach ($prompt in $prompts) {
                    $result = & $script:generateScript -Prompt $prompt -Model 'fal-ai/flux/dev'
                    $jobs += $result
                }

                $jobs.Count | Should -Be 3
                $jobs | ForEach-Object {
                    $_.Images.Count | Should -Be 1
                    $_.Images[0].Url | Should -BeLike 'https://fal.ai/output/fleet-*'
                    $_.Images[0].Width | Should -Be 1024
                }

                $urls = $jobs | ForEach-Object { $_.Images[0].Url }
                ($urls | Select-Object -Unique).Count | Should -Be 3
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should handle partial fleet failure without losing successful results' {
            $global:partialFleetCall = 0
            Mock Invoke-RestMethod {
                $global:partialFleetCall++
                if ($global:partialFleetCall -eq 2) {
                    throw [System.Net.WebException]::new('The remote server returned an error: (500) Internal Server Error.')
                }
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = "https://fal.ai/output/partial-$($global:partialFleetCall).png"
                        width  = 1024
                        height = 1024
                    })
                    seed = $global:partialFleetCall
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $prompts = @('Prompt A', 'Prompt B', 'Prompt C')
                $successes = @()
                $failures = @()

                foreach ($prompt in $prompts) {
                    try {
                        $result = & $script:generateScript -Prompt $prompt -Model 'fal-ai/flux/dev'
                        $successes += $result
                    }
                    catch {
                        $failures += [PSCustomObject]@{ Prompt = $prompt; Error = $_.Exception.Message }
                    }
                }

                $successes.Count | Should -Be 2
                $failures.Count | Should -Be 1
                $failures[0].Prompt | Should -Be 'Prompt B'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Pipeline pattern: generate → process → validate → deliver' {
        It 'Should execute a full 4-stage pipeline via workflow engine' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{
                            url    = 'https://fal.ai/output/pipeline-gen.png'
                            width  = 1024
                            height = 1024
                        })
                        seed = 42
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    return [PSCustomObject]@{
                        image = [PSCustomObject]@{
                            url    = 'https://fal.ai/output/pipeline-upscaled.png'
                            width  = 2048
                            height = 2048
                        }
                    }
                }
                return $null
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{
                        name      = 'generate'
                        model     = 'fal-ai/flux/dev'
                        params    = @{ prompt = 'Product photo of a watch on marble' }
                        dependsOn = @()
                    }
                    @{
                        name      = 'upscale'
                        model     = 'fal-ai/aura-sr'
                        params    = @{ scale = 2 }
                        dependsOn = @('generate')
                    }
                )

                $result = & $script:workflowScript -Name 'pipeline-test' -Steps $steps
                $result.WorkflowName | Should -Be 'pipeline-test'
                $result.Steps.Count | Should -Be 2
                $result.Steps[0].StepName | Should -Be 'generate'
                $result.Steps[0].Status | Should -Be 'Completed'
                $result.Steps[1].StepName | Should -Be 'upscale'
                $result.Steps[1].Status | Should -Be 'Completed'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should abort pipeline when an intermediate step fails' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{
                            url = 'https://fal.ai/output/will-fail-next.png'
                            width = 512; height = 512
                        })
                        seed = 1
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    throw [System.Net.WebException]::new('The remote server returned an error: (503) Service Unavailable.')
                }
                return $null
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'test' }; dependsOn = @() }
                    @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{ scale = 2 };       dependsOn = @('generate') }
                )

                { & $script:workflowScript -Name 'fail-pipeline' -Steps $steps } |
                    Should -Throw
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Variant generation with quality comparison' {
        It 'Should generate variants with different models and compare quality' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{
                            url = 'https://fal.ai/output/variant-dev.png'
                            width = 1024; height = 1024
                        })
                        seed = 42
                    }
                }
                if ($Uri -like '*flux/schnell*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{
                            url = 'https://fal.ai/output/variant-schnell.png'
                            width = 1024; height = 1024
                        })
                        seed = 42
                    }
                }
                return $null
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $prompt = 'A detailed illustration of a mechanical clock'

                $devResult = & $script:generateScript -Prompt $prompt -Model 'fal-ai/flux/dev'
                $schnellResult = & $script:generateScript -Prompt $prompt -Model 'fal-ai/flux/schnell'

                $devResult.Images[0].Width | Should -Be 1024
                $schnellResult.Images[0].Width | Should -Be 1024

                # Both variants should produce valid outputs
                $devResult.Images[0].Url | Should -BeLike 'https://fal.ai/*'
                $schnellResult.Images[0].Url | Should -BeLike 'https://fal.ai/*'

                # URLs should differ (different model outputs)
                $devResult.Images[0].Url | Should -Not -Be $schnellResult.Images[0].Url
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should measure and compare quality metrics across variants' {
            $variantA = New-MockImageFile -Path (Join-Path $script:testDir 'variant-a.png')
            $variantB = New-MockImageFile -Path (Join-Path $script:testDir 'variant-b.png')

            $qualityA = & $script:qualityScript -ImagePath $variantA.FullName
            $qualityB = & $script:qualityScript -ImagePath $variantB.FullName

            # Both should produce valid quality measurements
            $qualityA.FileSize | Should -BeGreaterThan 0
            $qualityB.FileSize | Should -BeGreaterThan 0
            $qualityA.MeanBrightness | Should -Not -Be -1
            $qualityB.MeanBrightness | Should -Not -Be -1

            # Compare with SSIM
            $comparison = & $script:qualityScript -ImagePath $variantA.FullName -ReferenceImagePath $variantB.FullName
            $comparison.SSIM | Should -BeGreaterThan 0
        }
    }
}
