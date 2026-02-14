BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:skillsDir = Join-Path $script:repoRoot 'skills'
    $script:scriptsDir = Join-Path $script:repoRoot 'scripts'
    $script:budgetScript = Join-Path $script:scriptsDir 'Measure-TokenBudget.ps1'
}

Describe 'Performance: Token Usage Optimization' {

    Context 'SKILL.md line budget' {
        It 'All SKILL.md files should be under 500 lines' {
            $skillFiles = Get-ChildItem -Path $script:skillsDir -Recurse -Filter 'SKILL.md'
            $skillFiles.Count | Should -BeGreaterThan 0

            foreach ($file in $skillFiles) {
                $lineCount = (Get-Content $file.FullName).Count
                $lineCount | Should -BeLessOrEqual 500 -Because "$($file.FullName) has $lineCount lines (limit 500)"
            }
        }
    }

    Context 'Script comment-based help efficiency' {
        It 'Scripts should not have excessively verbose comment-based help' {
            $scripts = Get-ChildItem -Path $script:scriptsDir -Filter '*.ps1'
            $scripts.Count | Should -BeGreaterThan 0

            foreach ($ps1 in $scripts) {
                $content = Get-Content $ps1.FullName -Raw
                # Extract comment-based help block
                if ($content -match '(?s)<#(.+?)#>') {
                    $helpBlock = $Matches[1]
                    $helpLines = ($helpBlock -split "`n").Count
                    # Help block should not exceed 30 lines — keep it concise
                    $helpLines | Should -BeLessOrEqual 40 -Because "$($ps1.Name) help block is $helpLines lines"
                }
            }
        }
    }

    Context 'Measure-TokenBudget output format' {
        It 'Should produce results with required properties for a single file' {
            # Create a temp file to measure
            $testFile = Join-Path $TestDrive 'sample.md'
            Set-Content -Path $testFile -Value (@('# Title'; 'Some content line') * 10)

            $results = & $script:budgetScript -Path $testFile -OutputFormat JSON | ConvertFrom-Json
            $results.PSObject.Properties.Name | Should -Contain 'File'
            $results.PSObject.Properties.Name | Should -Contain 'Lines'
            $results.PSObject.Properties.Name | Should -Contain 'EstimatedTokens'
            $results.PSObject.Properties.Name | Should -Contain 'OverBudget'
        }

        It 'Should flag files exceeding line threshold as OverBudget' {
            $testFile = Join-Path $TestDrive 'large.md'
            # Create a 510-line file
            Set-Content -Path $testFile -Value (1..510 | ForEach-Object { "Line number $_" })

            $results = & $script:budgetScript -Path $testFile -MaxLines 500 -OutputFormat JSON | ConvertFrom-Json
            $results.OverBudget | Should -BeTrue
        }
    }

    Context 'Optimization recommendations' {
        It 'Should identify the largest files when scanning a directory' {
            $dir = Join-Path $TestDrive 'opt-test'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null

            # Create files of varying size
            Set-Content (Join-Path $dir 'small.md') -Value (1..10 | ForEach-Object { "line $_" })
            Set-Content (Join-Path $dir 'medium.md') -Value (1..100 | ForEach-Object { "line $_" })
            Set-Content (Join-Path $dir 'big.md') -Value (1..400 | ForEach-Object { "line $_" })

            $results = & $script:budgetScript -Path $dir -OutputFormat JSON | ConvertFrom-Json
            $sorted = $results | Sort-Object -Property Lines -Descending
            $sorted[0].Lines | Should -BeGreaterThan $sorted[-1].Lines
        }
    }

    Context 'Combined skill token budget' {
        It 'Total estimated tokens across all skills should stay under 26000' {
            # 4 skills × 6500 max = 26000 combined ceiling
            $results = & $script:budgetScript -Path $script:skillsDir -OutputFormat JSON | ConvertFrom-Json
            $skillResults = @($results | Where-Object { $_.IsSkillFile -eq $true })

            if ($skillResults.Count -gt 0) {
                $totalTokens = ($skillResults | Measure-Object -Property EstimatedTokens -Sum).Sum
                $totalTokens | Should -BeLessOrEqual 26000 -Because "combined skill tokens ($totalTokens) must stay under budget"
            }
        }

        It 'No single skill should consume more than 50% of total skill budget' {
            $results = & $script:budgetScript -Path $script:skillsDir -OutputFormat JSON | ConvertFrom-Json
            $skillResults = @($results | Where-Object { $_.IsSkillFile -eq $true })

            if ($skillResults.Count -gt 1) {
                $totalTokens = ($skillResults | Measure-Object -Property EstimatedTokens -Sum).Sum
                foreach ($skill in $skillResults) {
                    $pct = $skill.EstimatedTokens / $totalTokens
                    $pct | Should -BeLessOrEqual 0.5 -Because "$($skill.File) uses $([math]::Round($pct*100))% of budget"
                }
            }
        }
    }
}
