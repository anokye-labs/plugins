BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
}

Describe 'Media Pipeline End-to-End' {
    Context 'Project structure validation' {
        It 'Should have all required script files' {
            Assert-FileStructure -BasePath $script:repoRoot -Paths @(
                'scripts/Invoke-FalGenerate.ps1'
                'scripts/Test-ImageSorcery.ps1'
                'scripts/FalAi.psm1'
            )
        }

        It 'Should have skill definitions' {
            Assert-FileStructure -BasePath $script:repoRoot -Paths @(
                'skills/image-sorcery/SKILL.md'
            )
        }

        It 'Should have test infrastructure' {
            Assert-FileStructure -BasePath $script:repoRoot -Paths @(
                'tests/helpers/TestHelper.psm1'
                'tests/e2e'
            )
        }

        It 'Should load TestHelper module successfully' {
            $module = Get-Module -Name TestHelper
            $module | Should -Not -BeNullOrEmpty
            $module.ExportedFunctions.Keys | Should -Contain 'New-MockImageFile'
        }
    }
}
