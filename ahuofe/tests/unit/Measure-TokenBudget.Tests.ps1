BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:ScriptPath = Join-Path $PSScriptRoot '..\..\scripts\Measure-TokenBudget.ps1'
}

Describe 'Measure-TokenBudget' {
    BeforeAll {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "tokenbudget-tests-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Single file counting' {
        It 'Should count lines and estimate tokens for a single file' {
            $filePath = Join-Path $script:testDir 'sample.md'
            Set-Content -Path $filePath -Value @('Line one with some words', 'Line two with more words', 'Line three')
            $result = & $script:ScriptPath -Path $filePath -OutputFormat JSON | ConvertFrom-Json
            $result.Lines | Should -Be 3
            $result.EstimatedTokens | Should -BeGreaterThan 0
        }

        It 'Should return OverBudget false for small files' {
            $filePath = Join-Path $script:testDir 'small.md'
            Set-Content -Path $filePath -Value @('Hello world')
            $result = & $script:ScriptPath -Path $filePath -OutputFormat JSON | ConvertFrom-Json
            $result.OverBudget | Should -Be $false
        }
    }

    Context 'Directory recursion' {
        It 'Should recurse into subdirectories and find multiple files' {
            $subDir = Join-Path $script:testDir 'subdir'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            Set-Content -Path (Join-Path $script:testDir 'root.md') -Value @('root content')
            Set-Content -Path (Join-Path $subDir 'nested.md') -Value @('nested content')
            $results = & $script:ScriptPath -Path $script:testDir -OutputFormat JSON | ConvertFrom-Json
            $results.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Over-budget flagging' {
        It 'Should flag file as over budget when exceeding max lines' {
            $filePath = Join-Path $script:testDir 'big.md'
            $lines = 1..600 | ForEach-Object { "Line $_ with some words to test token estimation" }
            Set-Content -Path $filePath -Value $lines
            $result = & $script:ScriptPath -Path $filePath -MaxLines 500 -OutputFormat JSON | ConvertFrom-Json
            $result.OverBudget | Should -Be $true
            $result.Lines | Should -Be 600
        }
    }

    Context 'SKILL.md handling' {
        It 'Should apply 500-line limit for SKILL.md files' {
            $filePath = Join-Path $script:testDir 'SKILL.md'
            Set-Content -Path $filePath -Value @('# Test Skill', 'Description here')
            $result = & $script:ScriptPath -Path $filePath -OutputFormat JSON | ConvertFrom-Json
            $result.IsSkillFile | Should -Be $true
            $result.MaxLines | Should -Be 500
        }
    }
}
