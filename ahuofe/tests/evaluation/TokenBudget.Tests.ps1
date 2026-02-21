BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:ScriptPath = Resolve-Path "$PSScriptRoot/../../scripts/Measure-TokenBudget.ps1"
}

Describe 'Token Budget Evaluation' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "tokbudget-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'When validating skill file line limits' {
        It 'Should pass for a small SKILL.md file' {
            $skillFile = Join-Path $script:TempDir 'SKILL.md'
            $lines = 1..50 | ForEach-Object { "Line $_ of the skill file with some content" }
            $lines | Set-Content -Path $skillFile

            $result = & $script:ScriptPath -Path $skillFile -OutputFormat JSON | ConvertFrom-Json
            $result.Lines | Should -Be 50
            $result.OverBudget | Should -BeFalse
            $result.IsSkillFile | Should -BeTrue
        }

        It 'Should flag a SKILL.md file over 500 lines' {
            $skillFile = Join-Path $script:TempDir 'SKILL.md'
            $lines = 1..550 | ForEach-Object { "Line $_ with words to count for token estimation" }
            $lines | Set-Content -Path $skillFile

            $result = & $script:ScriptPath -Path $skillFile -OutputFormat JSON | ConvertFrom-Json
            $result.Lines | Should -Be 550
            $result.OverBudget | Should -BeTrue
        }
    }

    Context 'When estimating tokens' {
        It 'Should estimate tokens using word count heuristic' {
            $testFile = Join-Path $script:TempDir 'test-doc.md'
            $lines = 1..10 | ForEach-Object { "This is a line with several words in it for testing" }
            $lines | Set-Content -Path $testFile

            $result = & $script:ScriptPath -Path $testFile -OutputFormat JSON | ConvertFrom-Json
            $result.EstimatedTokens | Should -BeGreaterThan 0
            $result.Words | Should -BeGreaterThan 0
        }
    }

    Context 'When scanning a directory' {
        It 'Should analyze all eligible files recursively' {
            $subDir = Join-Path $script:TempDir 'subdir'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            "File A content" | Set-Content (Join-Path $script:TempDir 'a.md')
            "File B content" | Set-Content (Join-Path $subDir 'b.ps1')

            $json = & $script:ScriptPath -Path $script:TempDir -OutputFormat JSON
            $results = $json | ConvertFrom-Json
            @($results).Count | Should -BeGreaterOrEqual 2
        }
    }
}
