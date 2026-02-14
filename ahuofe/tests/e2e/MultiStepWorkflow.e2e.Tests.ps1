BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:workflowScript = Join-Path $script:repoRoot 'scripts' 'New-FalWorkflow.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'E2E: Multi-Step Workflow Pipelines' {
    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Text-to-Image then Upscale pipeline' {
        It 'Should generate an image and upscale it in sequence' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/gen-001.png'; width = 1024; height = 1024 })
                        seed   = 42
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/upscaled-001.png'; width = 4096; height = 4096 })
                    }
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A sunset over mountains' }; dependsOn = @() }
                    @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('generate') }
                )
                $result = & $script:workflowScript -Name 'gen-upscale' -Steps $steps
                $result.WorkflowName | Should -Be 'gen-upscale'
                $result.Steps.Count | Should -Be 2
                $result.Steps[0].Status | Should -Be 'Completed'
                $result.Steps[1].Status | Should -Be 'Completed'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should pass generated image URL to the upscale step' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/chain-img.png'; width = 1024; height = 1024 })
                        seed   = 7
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    $parsed = $Body | ConvertFrom-Json
                    $parsed.image_url | Should -Be 'https://fal.ai/output/chain-img.png'
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/chain-up.png'; width = 4096; height = 4096 })
                    }
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A cat' }; dependsOn = @() }
                    @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('generate') }
                )
                $result = & $script:workflowScript -Name 'chain-test' -Steps $steps
                $result.Steps | ForEach-Object { $_.Status | Should -Be 'Completed' }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Text-to-Image then Edit then Upscale pipeline' {
        It 'Should execute a three-step generate → inpaint → upscale pipeline' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/base.png'; width = 1024; height = 1024 })
                        seed   = 1
                    }
                }
                if ($Uri -like '*inpainting*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/edited.png'; width = 1024; height = 1024 })
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/final.png'; width = 4096; height = 4096 })
                    }
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev';    params = @{ prompt = 'A room interior' }; dependsOn = @() }
                    @{ name = 'edit';     model = 'fal-ai/inpainting';  params = @{ prompt = 'Add a plant'; mask_url = 'https://example.com/mask.png' }; dependsOn = @('generate') }
                    @{ name = 'upscale';  model = 'fal-ai/aura-sr';     params = @{}; dependsOn = @('edit') }
                )
                $result = & $script:workflowScript -Name 'gen-edit-upscale' -Steps $steps
                $result.Steps.Count | Should -Be 3
                $result.Steps | ForEach-Object { $_.Status | Should -Be 'Completed' }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Text-to-Image then Image-to-Video pipeline' {
        It 'Should generate an image and animate it to video' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/scene.png'; width = 1024; height = 1024 })
                        seed   = 55
                    }
                }
                if ($Method -eq 'POST' -and $Uri -like '*queue*') {
                    return [PSCustomObject]@{ request_id = 'req-vid-001' }
                }
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                if ($Method -eq 'GET') {
                    return [PSCustomObject]@{
                        video = [PSCustomObject]@{ url = 'https://fal.ai/output/animated.mp4' }
                    }
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A waterfall' }; dependsOn = @() }
                    @{ name = 'animate';  model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'Slow pan' }; dependsOn = @('generate') }
                )
                $result = & $script:workflowScript -Name 'img-to-vid' -Steps $steps
                $result.Steps.Count | Should -Be 2
                $result.Steps[0].Status | Should -Be 'Completed'
                $result.Steps[1].Status | Should -Be 'Completed'
                $result.Steps[1].Output.video.url | Should -BeLike '*animated*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Workflow with quality checkpoints' {
        It 'Should validate output dimensions at each step' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/qc-gen.png'; width = 1024; height = 1024 })
                        seed   = 10
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/qc-up.png'; width = 4096; height = 4096 })
                    }
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'Quality check' }; dependsOn = @() }
                    @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('generate') }
                )
                $result = & $script:workflowScript -Name 'qc-workflow' -Steps $steps

                # Checkpoint: generation output has expected resolution
                $genOutput = $result.Steps | Where-Object { $_.StepName -eq 'generate' }
                $genOutput.Output.images[0].width | Should -Be 1024

                # Checkpoint: upscale output is higher resolution
                $upOutput = $result.Steps | Where-Object { $_.StepName -eq 'upscale' }
                $upOutput.Output.images[0].width | Should -BeGreaterThan $genOutput.Output.images[0].width
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Partial workflow failure' {
        It 'Should fail the workflow when a middle step fails' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/partial.png'; width = 1024; height = 1024 })
                        seed   = 3
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    throw [System.Net.WebException]::new('The remote server returned an error: (500) Internal Server Error.')
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'Partial fail' }; dependsOn = @() }
                    @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('generate') }
                )
                { & $script:workflowScript -Name 'partial-fail' -Steps $steps } | Should -Throw
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should complete first step even when second step fails' {
            Mock Invoke-RestMethod {
                param($Uri)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/ok.png'; width = 1024; height = 1024 })
                        seed   = 1
                    }
                }
                if ($Uri -like '*aura-sr*') {
                    throw [System.Net.WebException]::new('Service unavailable')
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'OK step' }; dependsOn = @() }
                    @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('generate') }
                )
                try { & $script:workflowScript -Name 'partial' -Steps $steps } catch {}

                # Verify the first step API call was made
                Should -Invoke Invoke-RestMethod -ModuleName FalAi -ParameterFilter {
                    $Uri -like '*flux/dev*'
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Workflow output structure' {
        It 'Should return workflow metadata with name and step details' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/output/meta.png'; width = 512; height = 512 })
                    seed   = 99
                }
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'single'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'metadata test' }; dependsOn = @() }
                )
                $result = & $script:workflowScript -Name 'meta-wf' -Steps $steps
                $result.PSObject.Properties.Name | Should -Contain 'WorkflowName'
                $result.PSObject.Properties.Name | Should -Contain 'Steps'
                $result.Steps[0].PSObject.Properties.Name | Should -Contain 'StepName'
                $result.Steps[0].PSObject.Properties.Name | Should -Contain 'Model'
                $result.Steps[0].PSObject.Properties.Name | Should -Contain 'Status'
                $result.Steps[0].PSObject.Properties.Name | Should -Contain 'Output'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }
}
