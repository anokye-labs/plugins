# PRTriageAutomation.Unit.Tests.ps1
# Pester 5 tests for PR triage automation scripts

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../../omanfo/scripts/pr-automation"
}

Describe "Get-ThreadDisposition" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Get-ThreadDisposition.ps1"
    }

    Context "Parameter validation" {
        It "Should require Body parameter" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters['Body'].Attributes.Mandatory | Should -Be $true
        }

        It "Should require Author parameter" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters['Author'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context "Security patterns → fix" {
        It "Should classify SQL injection comments as fix/critical" {
            $result = & $scriptPath -Body "This has a SQL injection vulnerability via string concatenation" -Author "devin-ai-integration[bot]"
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'critical'
        }

        It "Should classify XSS comments as fix/critical" {
            $result = & $scriptPath -Body "Potential XSS vulnerability with unescaped user input" -Author "copilot-pull-request-reviewer[bot]"
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'critical'
        }

        It "Should classify hardcoded secrets as fix/critical" {
            $result = & $scriptPath -Body "Found hardcoded API key in the configuration" -Author "devin-ai-integration[bot]"
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'critical'
        }
    }

    Context "Severity badges → fix" {
        It "Should classify P1 badge comments as fix/high" {
            $result = & $scriptPath -Body '**<sub>![P1 Badge](https://img.shields.io/badge/P1-orange)</sub> Remove direct vision-llm chain guidance**' -Author "chatgpt-codex-connector[bot]"
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'high'
        }

        It "Should classify explicit P1 severity as fix/high" {
            $result = & $scriptPath -Body "This needs to be fixed urgently" -Author "chatgpt-codex-connector[bot]" -Severity "P1"
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'high'
        }
    }

    Context "Suggestion blocks → fix" {
        It "Should classify comments with suggestion blocks as fix/medium" {
            $body = @"
Please rename the targets to the actual node types:
``````suggestion
| llm | output (text) | text-to-image (as prompt) |
``````
"@
            $result = & $scriptPath -Body $body -Author "copilot-pull-request-reviewer[bot]"
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'medium'
        }

        It "Should classify -HasSuggestion switch as fix/medium" {
            $result = & $scriptPath -Body "Consider this change" -Author "devin-ai-integration[bot]" -HasSuggestion
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'medium'
        }
    }

    Context "Breaking/functional patterns → fix" {
        It "Should classify 'does not work' as fix" {
            $result = & $scriptPath -Body "The auto-inject does not work for text outputs, only image_url" -Author "chatgpt-codex-connector[bot]"
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'medium'
        }

        It "Should classify 'will cause failure' as fix" {
            $result = & $scriptPath -Body "This will cause failures when users follow the documented chaining pattern" -Author "devin-ai-integration[bot]"
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'medium'
        }
    }

    Context "Architecture concerns → needs-human" {
        It "Should classify design questions as needs-human" {
            $result = & $scriptPath -Body "This is a design decision that affects backward compatibility" -Author "devin-ai-integration[bot]"
            $result.Disposition | Should -Be 'needs-human'
            $result.Priority | Should -Be 'high'
        }

        It "Should classify human comments as needs-human by default" {
            $result = & $scriptPath -Body "I think this approach could be improved" -Author "hoopsomuah"
            $result.Disposition | Should -Be 'needs-human'
            $result.Priority | Should -Be 'medium'
        }

        It "Should classify human test-request as needs-human, not create-issue" {
            $result = & $scriptPath -Body "Missing test coverage for this new function" -Author "hoopsomuah"
            $result.Disposition | Should -Be 'needs-human'
            $result.Priority | Should -Be 'medium'
        }

        It "Should classify human nit as needs-human, not resolve" {
            $result = & $scriptPath -Body "nit: rename this variable" -Author "hoopsomuah"
            $result.Disposition | Should -Be 'needs-human'
            $result.Priority | Should -Be 'medium'
        }
    }

    Context "Test coverage requests → create-issue" {
        It "Should classify missing test comments as create-issue" {
            $result = & $scriptPath -Body "Missing test coverage for this new function" -Author "devin-ai-integration[bot]"
            $result.Disposition | Should -Be 'create-issue'
            $result.Priority | Should -Be 'low'
        }
    }

    Context "Informational / noise → resolve" {
        It "Should classify Codex useful-reaction pattern as resolve" {
            $result = & $scriptPath -Body "Some feedback here. Useful? React with 👍 / 👎." -Author "chatgpt-codex-connector[bot]"
            $result.Disposition | Should -Be 'resolve'
            $result.Priority | Should -Be 'low'
        }

        It "Should classify nit comments as resolve" {
            $result = & $scriptPath -Body "nit: consider using a more descriptive variable name" -Author "devin-ai-integration[bot]"
            $result.Disposition | Should -Be 'resolve'
            $result.Priority | Should -Be 'low'
        }

        It "Should classify low-severity bot comments as resolve" {
            $result = & $scriptPath -Body "Minor documentation inconsistency" -Author "devin-ai-integration[bot]" -Severity "P4"
            $result.Disposition | Should -Be 'resolve'
            $result.Priority | Should -Be 'low'
        }

        It "Should classify generic bot comments as resolve" {
            $result = & $scriptPath -Body "This looks generally fine but could be cleaner" -Author "devin-ai-integration[bot]"
            $result.Disposition | Should -Be 'resolve'
            $result.Priority | Should -Be 'low'
        }
    }

    Context "Priority ordering - security wins over informational" {
        It "Should classify security nit as fix, not resolve" {
            $result = & $scriptPath -Body "nit: this has a potential SQL injection issue" -Author "devin-ai-integration[bot]"
            $result.Disposition | Should -Be 'fix'
            $result.Priority | Should -Be 'critical'
        }
    }
}

Describe "Measure-RoundComplexity" {
    BeforeAll {
        $scriptPath = Join-Path $scriptsPath "Measure-RoundComplexity.ps1"
    }

    Context "Parameter validation" {
        It "Should require Threads parameter" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters['Threads'].Attributes.Mandatory | Should -Be $true
        }

        It "Should require CurrentRound parameter" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters['CurrentRound'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context "Simple round - single suggestion" {
        It "Should classify a single suggestion fix as simple" {
            $threads = @(
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$true; FilePath='docs/README.md' }
            )
            $result = & $scriptPath -Threads $threads -CurrentRound 1
            $result.Tier | Should -Be 'simple'
            $result.CodingTimeoutMin | Should -Be 10
            $result.ShouldEscalate | Should -Be $false
        }
    }

    Context "Medium round - multiple code fixes" {
        It "Should classify multiple code fixes as medium" {
            $threads = @(
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$false; FilePath='src/api.ps1' },
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$false; FilePath='src/utils.ps1' },
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$true; FilePath='src/api.ps1' }
            )
            $result = & $scriptPath -Threads $threads -CurrentRound 1
            $result.Tier | Should -Be 'medium'
            $result.CodingTimeoutMin | Should -Be 30
            $result.FixCount | Should -Be 3
            $result.CodeFixCount | Should -Be 2
            $result.SuggestionCount | Should -Be 1
        }
    }

    Context "Complex round - critical with many files" {
        It "Should classify critical multi-file round as complex" {
            $threads = @(
                [PSCustomObject]@{ Disposition='fix'; Priority='critical'; HasSuggestion=$false; FilePath='src/a.ps1' },
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$false; FilePath='src/b.ps1' },
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$false; FilePath='src/c.ps1' },
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$false; FilePath='src/d.ps1' },
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$false; FilePath='src/e.ps1' }
            )
            $result = & $scriptPath -Threads $threads -CurrentRound 1
            $result.Tier | Should -Be 'complex'
            $result.CodingTimeoutMin | Should -Be 60
            $result.HasCritical | Should -Be $true
        }
    }

    Context "Escalation" {
        It "Should escalate when current round exceeds max" {
            $threads = @(
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$true; FilePath='doc.md' }
            )
            # Simple = max 2 rounds, current = 3
            $result = & $scriptPath -Threads $threads -CurrentRound 3
            $result.ShouldEscalate | Should -Be $true
            $result.RemainingRounds | Should -Be 0
        }

        It "Should respect MaxRoundsOverride" {
            $threads = @(
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$true; FilePath='doc.md' }
            )
            $result = & $scriptPath -Threads $threads -CurrentRound 3 -MaxRoundsOverride 5
            $result.ShouldEscalate | Should -Be $false
            $result.RemainingRounds | Should -Be 2
        }
    }

    Context "Non-fix threads ignored in complexity" {
        It "Should not count resolved threads in complexity" {
            $threads = @(
                [PSCustomObject]@{ Disposition='resolve'; Priority='low'; HasSuggestion=$false; FilePath='doc.md' },
                [PSCustomObject]@{ Disposition='fix'; Priority='medium'; HasSuggestion=$true; FilePath='doc.md' }
            )
            $result = & $scriptPath -Threads $threads -CurrentRound 1
            $result.FixCount | Should -Be 1
            $result.Tier | Should -Be 'simple'
        }
    }
}
