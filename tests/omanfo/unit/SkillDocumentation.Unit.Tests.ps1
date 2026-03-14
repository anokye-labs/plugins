# SkillDocumentation.Unit.Tests.ps1
# Pester tests validating SKILL.md structure for skill directories

BeforeAll {
    $skillsPath = Join-Path $PSScriptRoot "../../../omanfo/skills"
}

Describe "Skill Documentation - <SkillName>" -ForEach @(
    @{ SkillName = 'docx' }
    @{ SkillName = 'pdf' }
    @{ SkillName = 'pptx' }
    @{ SkillName = 'xlsx' }
    @{ SkillName = 'productivity' }
    @{ SkillName = 'doc-coauthoring' }
    @{ SkillName = 'internal-comms' }
    @{ SkillName = 'product-management' }
    @{ SkillName = 'skill-creator' }
    @{ SkillName = 'github-issue-creator' }
) {
    BeforeAll {
        $skillPath = Join-Path $skillsPath $SkillName
        $skillMdPath = Join-Path $skillPath "SKILL.md"
    }

    It "Should have a SKILL.md file" {
        $skillMdPath | Should -Exist
    }

    Context "Frontmatter validation" {
        BeforeAll {
            $content = Get-Content $skillMdPath -Raw -ErrorAction SilentlyContinue
            $lines = Get-Content $skillMdPath -ErrorAction SilentlyContinue

            # Parse frontmatter: content between first --- and second ---
            $frontmatter = $null
            $frontmatterName = $null
            $frontmatterDescription = $null

            if ($lines -and $lines.Count -gt 0) {
                $firstSeparator = -1
                $secondSeparator = -1

                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i].Trim() -eq '---') {
                        if ($firstSeparator -eq -1) {
                            $firstSeparator = $i
                        } elseif ($secondSeparator -eq -1) {
                            $secondSeparator = $i
                            break
                        }
                    }
                }

                if ($firstSeparator -ne -1 -and $secondSeparator -ne -1 -and $secondSeparator -gt ($firstSeparator + 1)) {
                    $frontmatter = $lines[($firstSeparator + 1)..($secondSeparator - 1)]

                    foreach ($line in $frontmatter) {
                        if ($line -match '^\s*name:\s*"?(.+?)"?\s*$') {
                            $frontmatterName = $Matches[1]
                        }
                        if ($line -match '^\s*description:\s*"?(.+?)"?\s*$') {
                            $frontmatterDescription = $Matches[1]
                        }
                    }
                }
            }
        }

        It "Should have valid frontmatter delimiters" {
            $lines[0].Trim() | Should -BeExactly '---'
            $frontmatter | Should -Not -BeNullOrEmpty
        }

        It "Should have a 'name' field in frontmatter" {
            $frontmatterName | Should -Not -BeNullOrEmpty
        }

        It "Should have a 'description' field in frontmatter" {
            $frontmatterDescription | Should -Not -BeNullOrEmpty
        }

        It "Should have a description of at least 50 characters" {
            $frontmatterDescription.Length | Should -BeGreaterOrEqual 50
        }
    }

    Context "Content structure validation" {
        BeforeAll {
            $content = Get-Content $skillMdPath -Raw -ErrorAction SilentlyContinue
            $lines = Get-Content $skillMdPath -ErrorAction SilentlyContinue
        }

        It "Should have at least one H2 heading" {
            $h2Headings = $lines | Where-Object { $_ -match '^## ' }
            $h2Headings | Should -Not -BeNullOrEmpty
        }

        It "Should have code blocks, tables, or structured lists" {
            $hasCodeBlocks = $content -match '```'
            $hasTables = $content -match '\|'
            $hasLists = $content -match '(?m)^[\s]*[-*]\s|^[\s]*\d+\.\s'
            ($hasCodeBlocks -or $hasTables -or $hasLists) | Should -BeTrue
        }

        It "Should be under 500 lines" {
            $lines.Count | Should -BeLessThan 500
        }
    }
}
