BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
}

Describe 'Gate 4: Repository Structure & Evaluation Framework' {
    Context 'Root Documentation' {
        It 'README.md exists' { 'README.md' | Should -Exist }
        It 'LICENSE exists' { 'LICENSE' | Should -Exist }
        It 'CONTRIBUTING.md exists' { 'CONTRIBUTING.md' | Should -Exist }
        It '.mcp.json exists' { '.mcp.json' | Should -Exist }
        It 'docs/ARCHITECTURE.md exists' { 'docs/ARCHITECTURE.md' | Should -Exist }
        It '.github/copilot-instructions.md exists' { '.github/copilot-instructions.md' | Should -Exist }
    }

    Context 'fal-workflow Skill' {
        It 'fal-workflow SKILL.md exists' {
            'skills/fal-workflow/SKILL.md' | Should -Exist
        }
    }

    Context 'E2E Test Coverage' {
        It 'TextToImage E2E test exists' {
            'tests/e2e/TextToImage.e2e.Tests.ps1' | Should -Exist
        }

        It 'CombinedWorkflow E2E test exists' {
            'tests/e2e/CombinedWorkflow.e2e.Tests.ps1' | Should -Exist
        }

        It 'QueueManagement E2E test exists' {
            'tests/e2e/QueueManagement.e2e.Tests.ps1' | Should -Exist
        }

        It 'ModelDiscovery E2E test exists' {
            'tests/e2e/ModelDiscovery.e2e.Tests.ps1' | Should -Exist
        }
    }

    Context 'Evaluation Framework' {
        It 'Evaluation README exists' {
            'tests/evaluation/README.md' | Should -Exist
        }

        It 'ImageQuality evaluation tests exist' {
            'tests/evaluation/ImageQuality.Tests.ps1' | Should -Exist
        }

        It 'VideoQuality evaluation tests exist' {
            'tests/evaluation/VideoQuality.Tests.ps1' | Should -Exist
        }

        It 'PerformanceBaseline evaluation tests exist' {
            'tests/evaluation/PerformanceBaseline.Tests.ps1' | Should -Exist
        }

        It 'CostTracking evaluation tests exist' {
            'tests/evaluation/CostTracking.Tests.ps1' | Should -Exist
        }

        It 'TokenBudget evaluation tests exist' {
            'tests/evaluation/TokenBudget.Tests.ps1' | Should -Exist
        }
    }
}
