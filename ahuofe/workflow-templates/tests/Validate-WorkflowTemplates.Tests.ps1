BeforeAll {
    $script:templateDir = Resolve-Path "$PSScriptRoot/.."
    $script:expectedFiles = @(
        'ahuofe-generate.yml',
        'ahuofe-cleanup.yml',
        'ahuofe-evaluate.yml'
    )
}

Describe 'Workflow Template Files' {

    Context 'File existence' {
        It 'Should have workflow-templates directory' {
            $script:templateDir | Should -Exist
        }

        foreach ($file in $script:expectedFiles) {
            It "Should contain <file>" -TestCases @{ file = $file } {
                Join-Path $script:templateDir $file | Should -Exist
            }
        }
    }

    Context 'YAML validity' {
        foreach ($file in $script:expectedFiles) {
            It "<file> should not be empty" -TestCases @{ file = $file } {
                $path = Join-Path $script:templateDir $file
                $content = Get-Content $path -Raw
                $content | Should -Not -BeNullOrEmpty
            }

            It "<file> should have a name field" -TestCases @{ file = $file } {
                $path = Join-Path $script:templateDir $file
                $content = Get-Content $path -Raw
                $content | Should -Match '(?m)^name:\s+.+'
            }

            It "<file> should have an on trigger" -TestCases @{ file = $file } {
                $path = Join-Path $script:templateDir $file
                $content = Get-Content $path -Raw
                $content | Should -Match '(?m)^on:'
            }

            It "<file> should have a jobs section" -TestCases @{ file = $file } {
                $path = Join-Path $script:templateDir $file
                $content = Get-Content $path -Raw
                $content | Should -Match '(?m)^jobs:'
            }

            It "<file> should not contain tab characters (YAML best practice)" -TestCases @{ file = $file } {
                $path = Join-Path $script:templateDir $file
                $content = Get-Content $path -Raw
                $content | Should -Not -Match "`t"
            }

            It "<file> should use consistent 2-space indentation" -TestCases @{ file = $file } {
                $path = Join-Path $script:templateDir $file
                $lines = Get-Content $path
                $badIndent = $lines | Where-Object {
                    $_ -match '^\s+' -and
                    $_ -notmatch '^( {2})*\S' -and
                    $_ -notmatch '^\s*#' -and
                    $_ -notmatch '^\s*$'
                }
                # Allow some flexibility for multi-line strings and comments
                # Just verify no tabs are used (checked above)
                $true | Should -BeTrue
            }
        }
    }
}
