BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
    $script:WorkflowScript = "$PSScriptRoot/../../scripts/New-FalWorkflow.ps1"
    $script:ValidateScript = "$PSScriptRoot/../../scripts/Test-FalWorkflow.ps1"
}

Describe 'Workflow Builder Integration' {

    BeforeEach {
        $script:savedFalKey = $env:FAL_KEY
        $env:FAL_KEY = 'test-key-for-mock'
    }
    AfterEach {
        $env:FAL_KEY = $script:savedFalKey
    }

    Context 'Single-Step Workflow' {
        It 'Should execute a single generate step with mocked API' {
            Mock -CommandName Invoke-FalApi -MockWith {
                [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.media/test.png'; width = 1024; height = 768 })
                    seed   = 42
                }
            }
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'A test image' }; dependsOn = @() }
            )

            $result = & $script:WorkflowScript -Name 'single-step' -Steps $steps
            $result.WorkflowName | Should -Be 'single-step'
            $result.Steps.Count | Should -Be 1
            $result.Steps[0].Status | Should -Be 'Completed'
            $result.Steps[0].Output.images[0].url | Should -Be 'https://fal.media/test.png'
        }
    }

    Context 'Multi-Step Pipeline' {
        It 'Should resolve dependencies and pass output between steps' {
            $script:callCount = 0
            Mock -CommandName Invoke-FalApi -MockWith {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.media/gen.png'; width = 1024; height = 768 })
                        seed   = 100
                    }
                }
                else {
                    [PSCustomObject]@{
                        image = [PSCustomObject]@{ url = 'https://fal.media/upscaled.png'; width = 2048; height = 1536 }
                    }
                }
            }

            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'Mountains' }; dependsOn = @() }
                @{ name = 'upscale'; model = 'fal-ai/aura-sr'
                   params = @{}; dependsOn = @('generate') }
            )

            $result = & $script:WorkflowScript -Name 'gen-upscale' -Steps $steps
            $result.Steps.Count | Should -Be 2
            $result.Steps[0].StepName | Should -Be 'generate'
            $result.Steps[1].StepName | Should -Be 'upscale'
            $result.Steps[1].Status | Should -Be 'Completed'
        }

        It 'Should execute a three-step pipeline in correct order' {
            Mock -CommandName Invoke-FalApi -MockWith {
                [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.media/out.png'; width = 1024; height = 768 })
                    seed   = 1
                }
            }
            Mock -CommandName Wait-FalJob -MockWith {
                [PSCustomObject]@{
                    video = [PSCustomObject]@{ url = 'https://fal.media/out.mp4' }
                }
            }

            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'A lake' }; dependsOn = @() }
                @{ name = 'upscale'; model = 'fal-ai/aura-sr'
                   params = @{}; dependsOn = @('generate') }
                @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'
                   params = @{ prompt = 'Ripples' }; dependsOn = @('upscale') }
            )

            $result = & $script:WorkflowScript -Name 'three-step' -Steps $steps
            $result.Steps.Count | Should -Be 3
            $result.Steps[0].StepName | Should -Be 'generate'
            $result.Steps[1].StepName | Should -Be 'upscale'
            $result.Steps[2].StepName | Should -Be 'animate'
            $result.Steps[2].Status | Should -Be 'Completed'
        }
    }

    Context 'Error Handling' {
        It 'Should propagate step failure with step name' {
            Mock -CommandName Invoke-FalApi -MockWith {
                throw 'HTTP 422: image_url is required'
            }

            $steps = @(
                @{ name = 'bad-step'; model = 'fal-ai/aura-sr'
                   params = @{}; dependsOn = @() }
            )

            { & $script:WorkflowScript -Name 'fail-test' -Steps $steps } |
                Should -Throw '*image_url is required*'
        }

        It 'Should fail on missing dependency step' {
            $steps = @(
                @{ name = 'upscale'; model = 'fal-ai/aura-sr'
                   params = @{}; dependsOn = @('nonexistent') }
            )

            { & $script:WorkflowScript -Name 'missing-dep' -Steps $steps } |
                Should -Throw "*depends on unknown step*"
        }
    }

    Context 'Circular Dependency Detection' {
        It 'Should detect a two-step cycle' {
            $steps = @(
                @{ name = 'a'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'X' }; dependsOn = @('b') }
                @{ name = 'b'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'Y' }; dependsOn = @('a') }
            )

            { & $script:WorkflowScript -Name 'cycle-test' -Steps $steps } |
                Should -Throw '*Circular dependency*'
        }

        It 'Should detect a three-step cycle' {
            $steps = @(
                @{ name = 'a'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'X' }; dependsOn = @('c') }
                @{ name = 'b'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'Y' }; dependsOn = @('a') }
                @{ name = 'c'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'Z' }; dependsOn = @('b') }
            )

            { & $script:WorkflowScript -Name 'cycle-3' -Steps $steps } |
                Should -Throw '*Circular dependency*'
        }
    }

    Context 'Output Passing Between Steps' {
        It 'Should inject image_url from generate step into upscale step' {
            Mock -CommandName Invoke-FalApi -MockWith {
                [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.media/gen.png'; width = 1024; height = 768 })
                    seed   = 42
                }
            }

            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'Test' }; dependsOn = @() }
                @{ name = 'upscale'; model = 'fal-ai/aura-sr'
                   params = @{}; dependsOn = @('generate') }
            )

            & $script:WorkflowScript -Name 'output-pass' -Steps $steps

            Should -Invoke -CommandName Invoke-FalApi -Times 2
        }
    }

    Context 'Dry-Run Validation' {
        It 'Should validate a correct workflow definition' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'
                   params = @{ prompt = 'A sunset' }; dependsOn = @() }
                @{ name = 'upscale'; model = 'fal-ai/aura-sr'
                   params = @{}; dependsOn = @('generate') }
            )

            $result = & $script:ValidateScript -Steps $steps -DryRun
            $result.Valid | Should -BeTrue
            $result.Errors.Count | Should -Be 0
            $result.StepCount | Should -Be 2
            $result.ExecutionOrder | Should -Contain 'generate'
            $result.ExecutionOrder | Should -Contain 'upscale'
        }

        It 'Should report errors for invalid workflow' {
            $steps = @(
                @{ name = 'upscale'; model = 'fal-ai/aura-sr'
                   params = @{}; dependsOn = @('missing') }
            )

            $result = & $script:ValidateScript -Steps $steps -DryRun
            $result.Valid | Should -BeFalse
            $result.Errors.Count | Should -BeGreaterThan 0
            $result.Errors | Should -Contain "Step 'upscale' depends on unknown step 'missing'."
        }

        It 'Should detect missing required parameters' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'
                   params = @{}; dependsOn = @() }
            )

            $result = & $script:ValidateScript -Steps $steps -DryRun
            $result.Valid | Should -BeFalse
            $result.Errors | Should -Contain "Step 'generate': missing required parameter 'prompt' for model 'fal-ai/flux/dev'."
        }
    }
}
