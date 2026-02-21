BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
}

Describe 'Gate 1: Foundation' {
    Context 'Core Infrastructure' {
        It 'Pester 5.x is installed' {
            $pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
            $pester | Should -Not -BeNullOrEmpty
            $pester.Version.Major | Should -BeGreaterOrEqual 5
        }

        It 'Pester config is valid' {
            $configHash = & "$PSScriptRoot/../.pester.ps1"
            $configHash | Should -Not -BeNullOrEmpty
            $configHash.Run.Path | Should -Be './tests'
        }

        It 'TestHelper module loads and exports functions' {
            $commands = Get-Command -Module TestHelper
            $commands | Should -Not -BeNullOrEmpty
            $commands.Name | Should -Contain 'New-MockFalApiResponse'
            $commands.Name | Should -Contain 'New-MockImageFile'
            $commands.Name | Should -Contain 'Assert-FileStructure'
            $commands.Name | Should -Contain 'Get-TestFixturePath'
        }
    }

    Context 'Repository Structure' {
        It 'Issue templates exist and are valid YAML' {
            $templates = Get-ChildItem '.github/ISSUE_TEMPLATE' -Filter *.yml
            $templates.Count | Should -BeGreaterOrEqual 3
            foreach ($t in $templates) {
                $content = Get-Content $t.FullName -Raw
                $content | Should -Not -BeNullOrEmpty
                $content | Should -Match 'name:'
            }
        }

        It 'PR template exists' { '.github/PULL_REQUEST_TEMPLATE.md' | Should -Exist }
        It 'CODEOWNERS exists' { '.github/CODEOWNERS' | Should -Exist }
        It 'SECURITY.md exists' { 'SECURITY.md' | Should -Exist }
        It '.gitignore exists' { '.gitignore' | Should -Exist }
    }

    Context 'Skill Definitions' {
        It 'ImageSorcery SKILL.md exists with required sections' {
            $content = Get-Content 'skills/image-sorcery/SKILL.md' -Raw
            $content | Should -Match '## Operation Tiers'
            $content | Should -Match '## Available Tools'
            $content | Should -Match '## Best Practices'
        }

        It 'Media Agents SKILL.md exists with required sections' {
            $content = Get-Content 'skills/media-agents/SKILL.md' -Raw
            $content | Should -Match '## 1\. Fleet Pattern'
            $content | Should -Match '## 6\. Error Handling'
            $content | Should -Match '## 7\. Available Agent Types'
        }
    }

    Context 'fal.ai Analysis' {
        It 'Bash analysis document exists' { 'docs/bash-analysis.md' | Should -Exist }

        It 'Bash analysis covers all script categories' {
            $content = Get-Content 'docs/bash-analysis.md' -Raw
            $content | Should -Match 'generate'
            $content | Should -Match 'upload'
            $content | Should -Match 'upscale'
        }
    }

    Context 'Documentation' {
        It 'User guides directory has content' {
            $guides = Get-ChildItem 'docs/user-guides' -Filter *.md
            $guides.Count | Should -BeGreaterOrEqual 3
        }

        It 'API reference directory has content' {
            $refs = Get-ChildItem 'docs/api-reference' -Filter *.md
            $refs.Count | Should -BeGreaterOrEqual 2
        }

        It 'Examples gallery directory has content' {
            $examples = Get-ChildItem 'docs/examples-gallery' -Filter *.md
            $examples.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Security Reviews' {
        It 'API key management doc exists' { 'docs/security/api-key-management.md' | Should -Exist }
        It 'Secret handling doc exists' { 'docs/security/secret-handling.md' | Should -Exist }

        It 'Security docs reference FAL_KEY' {
            $apiKey = Get-Content 'docs/security/api-key-management.md' -Raw
            $apiKey | Should -Match 'FAL_KEY'
        }
    }

    Context 'Test Fixtures' {
        It 'Mock API response fixture exists' {
            'tests/fixtures/mock-api-responses/fal-generate-success.json' | Should -Exist
        }

        It 'Mock fixture is valid JSON' {
            $json = Get-Content 'tests/fixtures/mock-api-responses/fal-generate-success.json' -Raw | ConvertFrom-Json
            $json | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Test Stubs Discoverable' {
        It 'Unit test files exist' {
            (Get-ChildItem 'tests/unit' -Filter *.Tests.ps1).Count | Should -BeGreaterOrEqual 3
        }

        It 'Integration test files exist' {
            (Get-ChildItem 'tests/integration' -Filter *.Tests.ps1).Count | Should -BeGreaterOrEqual 1
        }

        It 'E2E test files exist' {
            (Get-ChildItem 'tests/e2e' -Filter *.Tests.ps1).Count | Should -BeGreaterOrEqual 1
        }

        It 'Evaluation test files exist' {
            (Get-ChildItem 'tests/evaluation' -Filter *.Tests.ps1).Count | Should -BeGreaterOrEqual 1
        }
    }
}
