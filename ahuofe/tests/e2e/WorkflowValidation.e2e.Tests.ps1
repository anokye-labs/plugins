BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:validateScript = Join-Path $script:repoRoot 'scripts' 'Test-FalWorkflow.ps1'
}

Describe 'E2E: Workflow Validation via Test-FalWorkflow' {
    Context 'Valid workflow passes validation' {
        It 'Should validate a well-formed two-step workflow' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A landscape' }; dependsOn = @() }
                @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('generate') }
            )
            $result = & $script:validateScript -Steps $steps
            $result.Valid | Should -BeTrue
            $result.Errors.Count | Should -Be 0
            $result.StepCount | Should -Be 2
            $result.ExecutionOrder | Should -Be @('generate', 'upscale')
        }

        It 'Should validate a single-step workflow' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'Hello' }; dependsOn = @() }
            )
            $result = & $script:validateScript -Steps $steps
            $result.Valid | Should -BeTrue
            $result.StepCount | Should -Be 1
        }
    }

    Context 'Circular dependency detection' {
        It 'Should detect a direct circular dependency' {
            $steps = @(
                @{ name = 'a'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'x' }; dependsOn = @('b') }
                @{ name = 'b'; model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('a') }
            )
            $result = & $script:validateScript -Steps $steps
            $result.Valid | Should -BeFalse
            $result.Errors | Should -Not -BeNullOrEmpty
            ($result.Errors -join ' ') | Should -BeLike '*Circular dependency*'
        }

        It 'Should detect a self-referencing step' {
            $steps = @(
                @{ name = 'loop'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'self' }; dependsOn = @('loop') }
            )
            $result = & $script:validateScript -Steps $steps
            $result.Valid | Should -BeFalse
            ($result.Errors -join ' ') | Should -BeLike '*depends on itself*'
        }
    }

    Context 'Missing dependency detection' {
        It 'Should detect a reference to a non-existent step' {
            $steps = @(
                @{ name = 'upscale'; model = 'fal-ai/aura-sr'; params = @{}; dependsOn = @('generate') }
            )
            $result = & $script:validateScript -Steps $steps
            $result.Valid | Should -BeFalse
            ($result.Errors -join ' ') | Should -BeLike "*unknown step 'generate'*"
        }
    }

    Context 'Invalid model endpoint detection' {
        It 'Should warn on unknown model endpoint' {
            $steps = @(
                @{ name = 'gen'; model = 'fal-ai/nonexistent-model'; params = @{ prompt = 'test' }; dependsOn = @() }
            )
            $result = & $script:validateScript -Steps $steps
            # Unknown models produce warnings, not errors
            $result.Warnings | Should -Not -BeNullOrEmpty
            ($result.Warnings -join ' ') | Should -BeLike '*not in the known models list*'
        }
    }

    Context 'Missing required parameter detection' {
        It 'Should detect missing prompt for flux/dev' {
            $steps = @(
                @{ name = 'gen'; model = 'fal-ai/flux/dev'; params = @{}; dependsOn = @() }
            )
            $result = & $script:validateScript -Steps $steps
            $result.Valid | Should -BeFalse
            ($result.Errors -join ' ') | Should -BeLike "*missing required parameter 'prompt'*"
        }

        It 'Should accept auto-injected image_url for dependent steps' {
            $steps = @(
                @{ name = 'gen'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A cat' }; dependsOn = @() }
                @{ name = 'up';  model = 'fal-ai/aura-sr';  params = @{}; dependsOn = @('gen') }
            )
            $result = & $script:validateScript -Steps $steps
            # aura-sr requires image_url but it's auto-injected from dependency
            $result.Valid | Should -BeTrue
        }

        It 'Should detect missing image_url when step has no dependencies' {
            $steps = @(
                @{ name = 'up'; model = 'fal-ai/aura-sr'; params = @{}; dependsOn = @() }
            )
            $result = & $script:validateScript -Steps $steps
            $result.Valid | Should -BeFalse
            ($result.Errors -join ' ') | Should -BeLike "*missing required parameter 'image_url'*"
        }
    }

    Context 'Empty workflow validation' {
        It 'Should reject a workflow with no steps' {
            # PowerShell validates non-empty array at binding, so an empty array
            # is itself an error — the script cannot be invoked with zero steps.
            { & $script:validateScript -Steps @() } | Should -Throw
        }
    }
}
