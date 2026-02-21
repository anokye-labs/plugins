BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
}

Describe 'Gate 2: Implementation' {
    Context 'Core Module' {
        It 'FalAi.psm1 exists' {
            'scripts/FalAi.psm1' | Should -Exist
        }

        It 'FalAi.psm1 exports Invoke-FalApi function' {
            $content = Get-Content 'scripts/FalAi.psm1' -Raw
            $content | Should -Match 'function\s+Invoke-FalApi'
        }

        It 'FalAi.psm1 exports Get-FalApiKey function' {
            $content = Get-Content 'scripts/FalAi.psm1' -Raw
            $content | Should -Match 'function\s+Get-FalApiKey'
        }

        It 'FalAi.psm1 exports Send-FalFile function' {
            $content = Get-Content 'scripts/FalAi.psm1' -Raw
            $content | Should -Match 'function\s+Send-FalFile'
        }
    }

    Context 'Entry Point Scripts' {
        It 'Invoke-FalGenerate.ps1 exists' {
            'scripts/Invoke-FalGenerate.ps1' | Should -Exist
        }

        It 'Invoke-FalGenerate.ps1 accepts a Prompt parameter' {
            $content = Get-Content 'scripts/Invoke-FalGenerate.ps1' -Raw
            $content | Should -Match 'Prompt'
        }
    }

    Context 'fal.ai Skill Definition' {
        It 'fal-ai SKILL.md exists' {
            'skills/fal-ai/SKILL.md' | Should -Exist
        }

        It 'fal-ai SKILL.md is under 500 lines' {
            $lineCount = (Get-Content 'skills/fal-ai/SKILL.md').Count
            $lineCount | Should -BeLessOrEqual 500
        }

        It 'fal-ai SKILL.md references at least one model' {
            $content = Get-Content 'skills/fal-ai/SKILL.md' -Raw
            $content | Should -Match 'fal-ai/'
        }
    }

    Context 'Golden Prompts Dataset' {
        It 'golden-prompts.json exists' {
            'tests/fixtures/golden-prompts.json' | Should -Exist
        }

        It 'golden-prompts.json is valid JSON' {
            $json = Get-Content 'tests/fixtures/golden-prompts.json' -Raw | ConvertFrom-Json
            $json | Should -Not -BeNullOrEmpty
        }

        It 'golden-prompts.json has version field' {
            $json = Get-Content 'tests/fixtures/golden-prompts.json' -Raw | ConvertFrom-Json
            $json.version | Should -Be '1.0'
        }

        It 'golden-prompts.json has at least 20 prompts' {
            $json = Get-Content 'tests/fixtures/golden-prompts.json' -Raw | ConvertFrom-Json
            $json.prompts.Count | Should -BeGreaterOrEqual 20
        }

        It 'each golden prompt has required fields (id, category, prompt, model)' {
            $json = Get-Content 'tests/fixtures/golden-prompts.json' -Raw | ConvertFrom-Json
            foreach ($p in $json.prompts) {
                $p.id | Should -Not -BeNullOrEmpty
                $p.category | Should -Not -BeNullOrEmpty
                $p.prompt | Should -Not -BeNullOrEmpty
                $p.model | Should -Not -BeNullOrEmpty
            }
        }

        It 'golden prompts cover at least 5 categories' {
            $json = Get-Content 'tests/fixtures/golden-prompts.json' -Raw | ConvertFrom-Json
            $categories = $json.prompts | ForEach-Object { $_.category } | Sort-Object -Unique
            $categories.Count | Should -BeGreaterOrEqual 5
        }
    }

    Context 'Quality Thresholds' {
        It 'quality-thresholds.json exists' {
            'tests/fixtures/quality-thresholds.json' | Should -Exist
        }

        It 'quality-thresholds.json is valid JSON' {
            $json = Get-Content 'tests/fixtures/quality-thresholds.json' -Raw | ConvertFrom-Json
            $json | Should -Not -BeNullOrEmpty
        }

        It 'quality-thresholds.json has image section' {
            $json = Get-Content 'tests/fixtures/quality-thresholds.json' -Raw | ConvertFrom-Json
            $json.image | Should -Not -BeNullOrEmpty
        }

        It 'quality-thresholds.json has video section' {
            $json = Get-Content 'tests/fixtures/quality-thresholds.json' -Raw | ConvertFrom-Json
            $json.video | Should -Not -BeNullOrEmpty
        }

        It 'quality-thresholds.json has performance section' {
            $json = Get-Content 'tests/fixtures/quality-thresholds.json' -Raw | ConvertFrom-Json
            $json.performance | Should -Not -BeNullOrEmpty
            $json.performance.max_generation_time_seconds | Should -BeGreaterThan 0
        }

        It 'quality-thresholds.json has token_budget section' {
            $json = Get-Content 'tests/fixtures/quality-thresholds.json' -Raw | ConvertFrom-Json
            $json.token_budget | Should -Not -BeNullOrEmpty
            $json.token_budget.skill_file_max_lines | Should -Be 500
        }
    }

    Context 'Measurement Scripts' {
        It 'at least 5 measurement or validation scripts exist' {
            $measureScripts = Get-ChildItem 'scripts' -Filter 'Measure-*.ps1' -Recurse -ErrorAction SilentlyContinue
            $validateScripts = Get-ChildItem 'scripts' -Filter 'Test-*.ps1' -Recurse -ErrorAction SilentlyContinue
            $invokeScripts = Get-ChildItem 'scripts' -Filter 'Invoke-*.ps1' -Recurse -ErrorAction SilentlyContinue
            $total = @($measureScripts).Count + @($validateScripts).Count + @($invokeScripts).Count
            $total | Should -BeGreaterOrEqual 5
        }
    }

    Context 'Architecture Documentation' {
        It 'plugin-infrastructure.md exists' {
            'docs/architecture/plugin-infrastructure.md' | Should -Exist
        }

        It 'plugin-infrastructure.md covers data flow' {
            $content = Get-Content 'docs/architecture/plugin-infrastructure.md' -Raw
            $content | Should -Match 'Data Flow'
        }

        It 'plugin-infrastructure.md covers extension points' {
            $content = Get-Content 'docs/architecture/plugin-infrastructure.md' -Raw
            $content | Should -Match 'Extension Points'
        }
    }

    Context 'Production Readiness' {
        It 'production-readiness.md exists' {
            'docs/production-readiness.md' | Should -Exist
        }

        It 'production-readiness.md has validation scripts section' {
            $content = Get-Content 'docs/production-readiness.md' -Raw
            $content | Should -Match 'Validation Scripts'
        }
    }
}
