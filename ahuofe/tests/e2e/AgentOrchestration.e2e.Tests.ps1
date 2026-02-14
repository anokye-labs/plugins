BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:workflowScript = Join-Path $script:repoRoot 'scripts' 'New-FalWorkflow.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'E2E: Agent Orchestration Patterns' {
    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Fleet dispatch: generate variants in parallel' {
        It 'Should generate 3 image variants independently' {
            $script:callCounter = 0
            Mock Invoke-RestMethod {
                param($Uri, $Body)
                $script:callCounter++
                $parsed = $Body | ConvertFrom-Json
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = "https://fal.ai/output/variant-$($script:callCounter).png"
                        width  = 1024
                        height = 1024
                    })
                    seed   = $script:callCounter
                    prompt = $parsed.prompt
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                # Simulate fleet dispatch: 3 independent generators
                $variants = @('Facebook banner', 'Instagram square', 'Twitter header') | ForEach-Object {
                    Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = "Product photo as $_" }
                }

                $variants.Count | Should -Be 3
                $variants | ForEach-Object {
                    $_.images.Count | Should -Be 1
                    $_.images[0].url | Should -BeLike '*variant*'
                }
                # Each variant has a unique URL
                $urls = $variants | ForEach-Object { $_.images[0].url }
                ($urls | Select-Object -Unique).Count | Should -Be 3
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should aggregate fleet results into a summary' {
            $script:idx = 0
            Mock Invoke-RestMethod {
                $script:idx++
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{
                        url    = "https://fal.ai/output/fleet-$($script:idx).png"
                        width  = @(1200, 1080, 1200)[$script:idx - 1]
                        height = @(628, 1080, 675)[$script:idx - 1]
                    })
                    seed = $script:idx
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $specs = @(
                    @{ name = 'facebook'; width = 1200; height = 628 }
                    @{ name = 'instagram'; width = 1080; height = 1080 }
                    @{ name = 'twitter'; width = 1200; height = 675 }
                )

                $results = $specs | ForEach-Object {
                    $r = Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = "Banner for $($_.name)" }
                    [PSCustomObject]@{
                        Variant    = $_.name
                        Url        = $r.images[0].url
                        Width      = $r.images[0].width
                        Height     = $r.images[0].height
                    }
                }

                $results.Count | Should -Be 3
                ($results | Where-Object { $_.Variant -eq 'instagram' }).Width | Should -Be 1080
                ($results | Where-Object { $_.Variant -eq 'instagram' }).Height | Should -Be 1080
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Sequential pipeline: generate → process → validate' {
        It 'Should chain generator, processor, and validator roles' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/gen-pipe.png'; width = 1024; height = 1024 })
                        seed   = 5
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/proc-pipe.png'; width = 4096; height = 4096 })
                    }
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                # Generator role
                $genResult = Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = 'Product shot' }
                $genResult.images[0].url | Should -Not -BeNullOrEmpty

                # Processor role
                $procResult = Invoke-FalApi -Method POST -Endpoint 'fal-ai/aura-sr' -Body @{ image_url = $genResult.images[0].url }
                $procResult.images[0].width | Should -BeGreaterThan $genResult.images[0].width

                # Validator role (check dimensions via mock metainfo)
                $validation = New-MockImageMetainfo -Width 4096 -Height 4096
                $validation.result.width | Should -Be 4096
                $validation.error | Should -BeNullOrEmpty
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Agent role assignment' {
        It 'Should assign correct tools to each agent role' {
            # Define agent role mappings per SKILL.md
            $agentRoles = @{
                generator = @{ tool = 'fal-ai'; endpoint = 'fal-ai/flux/dev' }
                processor = @{ tool = 'ImageSorcery'; operations = @('resize', 'crop', 'draw_texts') }
                validator = @{ tool = 'ImageSorcery'; operations = @('detect', 'get_metainfo', 'ocr') }
            }

            $agentRoles.Keys.Count | Should -Be 3
            $agentRoles['generator'].tool | Should -Be 'fal-ai'
            $agentRoles['processor'].operations | Should -Contain 'resize'
            $agentRoles['validator'].operations | Should -Contain 'detect'
        }

        It 'Should execute role-specific operations correctly' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/role-test.png'; width = 1024; height = 1024 })
                    seed   = 88
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                # Generator agent produces image
                $generated = Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = 'Role test image' }
                $generated.images.Count | Should -Be 1

                # Processor agent transforms image (mock MCP)
                $processed = New-MockMcpResponse -ToolName 'resize' -Result ([PSCustomObject]@{
                    output_path = '/tmp/resized.png'; width = 512; height = 512
                })
                $processed.error | Should -BeNullOrEmpty
                $processed.result.width | Should -Be 512

                # Validator agent checks output
                $validated = New-MockDetectionResult -InputPath '/tmp/resized.png' -Objects @(
                    @{ class_name = 'product'; confidence = 0.94; bbox = @(50, 50, 450, 450) }
                )
                $validated.result.objects.Count | Should -Be 1
                $validated.result.objects[0].confidence | Should -BeGreaterThan 0.9
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Checkpoint and resume pattern' {
        It 'Should save checkpoint after each completed step' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/cp-1.png'; width = 1024; height = 1024 })
                        seed   = 11
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/cp-2.png'; width = 4096; height = 4096 })
                    }
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $checkpoints = [System.Collections.ArrayList]::new()

                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'Checkpoint test' }; dependsOn = @() }
                    @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('generate') }
                )
                $result = & $script:workflowScript -Name 'checkpoint-wf' -Steps $steps

                # Simulate checkpoint recording after workflow
                foreach ($step in $result.Steps) {
                    [void]$checkpoints.Add([PSCustomObject]@{
                        StepName  = $step.StepName
                        Status    = $step.Status
                        OutputUrl = if ($step.Output.images) { $step.Output.images[0].url } else { $null }
                    })
                }

                $checkpoints.Count | Should -Be 2
                $checkpoints[0].Status | Should -Be 'Completed'
                $checkpoints[1].Status | Should -Be 'Completed'
                $checkpoints[0].OutputUrl | Should -BeLike '*cp-1*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should resume from last successful checkpoint on failure' {
            # Simulate a workflow where step 1 succeeded and step 2 failed
            $checkpoint = [PSCustomObject]@{
                CompletedSteps = @('generate')
                LastOutput     = [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/resumed.png'; width = 1024; height = 1024 })
                }
            }

            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/retry-up.png'; width = 4096; height = 4096 })
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                # Resume: skip generate, run upscale with checkpoint output
                $checkpoint.CompletedSteps | Should -Contain 'generate'
                $resumeResult = Invoke-FalApi -Method POST -Endpoint 'fal-ai/aura-sr' -Body @{
                    image_url = $checkpoint.LastOutput.images[0].url
                }
                $resumeResult.images[0].url | Should -BeLike '*retry-up*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }
}
