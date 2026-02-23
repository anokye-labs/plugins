# Initialize-AnokyeRepo.Unit.Tests.ps1
# Pester unit tests for the Initialize-AnokyeRepo.ps1 scaffolding script

BeforeAll {
    $scriptPath = Resolve-Path "$PSScriptRoot/../../../scripts/Initialize-AnokyeRepo.ps1"
}

Describe 'Initialize-AnokyeRepo' {

    Context 'Parameter validation' {
        It 'Has mandatory -Path parameter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'Path'
            $cmd.Parameters['Path'].Attributes.Mandatory | Should -Be $true
        }

        It 'Has mandatory -RepoName parameter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'RepoName'
            $cmd.Parameters['RepoName'].Attributes.Mandatory | Should -Be $true
        }

        It 'Has -IncludeTemplates switch parameter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'IncludeTemplates'
            $cmd.Parameters['IncludeTemplates'].ParameterType | Should -Be ([switch])
        }

        It 'Has -DryRun switch parameter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'DryRun'
            $cmd.Parameters['DryRun'].ParameterType | Should -Be ([switch])
        }
    }

    Context 'DryRun mode' {
        BeforeEach {
            $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "anokye-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $tempBase -Force | Out-Null
        }
        AfterEach {
            if (Test-Path $tempBase) { Remove-Item $tempBase -Recurse -Force }
        }

        It 'Returns a PSCustomObject result' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo' -DryRun
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Sets DryRun to true in result' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo' -DryRun
            $result.DryRun | Should -Be $true
        }

        It 'Does not create any directories on disk' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' -DryRun | Out-Null
            $repoPath = Join-Path $tempBase 'test-repo'
            Test-Path $repoPath | Should -Be $false
        }

        It 'Reports directories that would be created' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo' -DryRun
            $result.DirectoriesCreated | Should -Not -BeNullOrEmpty
            $result.DirectoriesCreated.Count | Should -BeGreaterThan 0
        }

        It 'Reports stub files that would be created in DryRun' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo' -DryRun
            $result.StubsCreated | Should -Not -BeNullOrEmpty
        }

        It 'Does not copy templates in DryRun without -IncludeTemplates' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo' -DryRun
            $result.TemplatesCopied | Should -BeNullOrEmpty
        }

        It 'Reports templates that would be copied in DryRun with -IncludeTemplates' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo' -DryRun -IncludeTemplates
            $result.TemplatesCopied | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Directory creation' {
        BeforeEach {
            $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "anokye-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $tempBase -Force | Out-Null
        }
        AfterEach {
            if (Test-Path $tempBase) { Remove-Item $tempBase -Recurse -Force }
        }

        It 'Creates the repo root directory' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            Test-Path (Join-Path $tempBase 'test-repo') | Should -Be $true
        }

        It 'Creates .github/skills directory' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            Test-Path (Join-Path $tempBase 'test-repo/.github/skills') | Should -Be $true
        }

        It 'Creates .github/workflows directory' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            Test-Path (Join-Path $tempBase 'test-repo/.github/workflows') | Should -Be $true
        }

        It 'Creates .github/ISSUE_TEMPLATE directory' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            Test-Path (Join-Path $tempBase 'test-repo/.github/ISSUE_TEMPLATE') | Should -Be $true
        }

        It 'Creates scripts directory' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            Test-Path (Join-Path $tempBase 'test-repo/scripts') | Should -Be $true
        }

        It 'Creates docs/adr directory' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            Test-Path (Join-Path $tempBase 'test-repo/docs/adr') | Should -Be $true
        }

        It 'Returns DryRun false for a real run' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.DryRun | Should -Be $false
        }

        It 'Returns correct RepoName in result' {
            $result = & $scriptPath -Path $tempBase -RepoName 'my-repo'
            $result.RepoName | Should -Be 'my-repo'
        }

        It 'Returns correct Path pointing to repo root' {
            $result = & $scriptPath -Path $tempBase -RepoName 'my-repo'
            $result.Path | Should -Be (Join-Path $tempBase 'my-repo')
        }

        It 'Tracks created directories in result' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.DirectoriesCreated | Should -Not -BeNullOrEmpty
        }

        It 'Tracks skipped directories when repo already exists' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.DirectoriesSkipped | Should -Not -BeNullOrEmpty
        }

        It 'Does not throw when directories already exist' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            { & $scriptPath -Path $tempBase -RepoName 'test-repo' } | Should -Not -Throw
        }
    }

    Context 'Stub file initialization' {
        BeforeEach {
            $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "anokye-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $tempBase -Force | Out-Null
        }
        AfterEach {
            if (Test-Path $tempBase) { Remove-Item $tempBase -Recurse -Force }
        }

        It 'Creates docs/adr/README.md stub' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            Test-Path (Join-Path $tempBase 'test-repo/docs/adr/README.md') | Should -Be $true
        }

        It 'ADR README stub contains repo name' {
            & $scriptPath -Path $tempBase -RepoName 'my-special-repo' | Out-Null
            $content = Get-Content (Join-Path $tempBase 'my-special-repo/docs/adr/README.md') -Raw
            $content | Should -Match 'my-special-repo'
        }

        It 'Tracks created stubs in result' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.StubsCreated | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Template copying with -IncludeTemplates' {
        BeforeEach {
            $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "anokye-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $tempBase -Force | Out-Null
        }
        AfterEach {
            if (Test-Path $tempBase) { Remove-Item $tempBase -Recurse -Force }
        }

        It 'Copies .gitignore when -IncludeTemplates is set' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' -IncludeTemplates | Out-Null
            Test-Path (Join-Path $tempBase 'test-repo/.gitignore') | Should -Be $true
        }

        It 'Tracks copied templates in result' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo' -IncludeTemplates
            $result.TemplatesCopied | Should -Not -BeNullOrEmpty
        }

        It 'Does not copy templates when -IncludeTemplates is not set' {
            & $scriptPath -Path $tempBase -RepoName 'test-repo' | Out-Null
            Test-Path (Join-Path $tempBase 'test-repo/.gitignore') | Should -Be $false
        }

        It 'TemplatesCopied is empty when -IncludeTemplates is not set' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.TemplatesCopied | Should -BeNullOrEmpty
        }
    }

    Context 'Result structure' {
        BeforeEach {
            $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "anokye-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $tempBase -Force | Out-Null
        }
        AfterEach {
            if (Test-Path $tempBase) { Remove-Item $tempBase -Recurse -Force }
        }

        It 'Result has RepoName property' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.PSObject.Properties.Name | Should -Contain 'RepoName'
        }

        It 'Result has Path property' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.PSObject.Properties.Name | Should -Contain 'Path'
        }

        It 'Result has DirectoriesCreated property' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.PSObject.Properties.Name | Should -Contain 'DirectoriesCreated'
        }

        It 'Result has DirectoriesSkipped property' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.PSObject.Properties.Name | Should -Contain 'DirectoriesSkipped'
        }

        It 'Result has StubsCreated property' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.PSObject.Properties.Name | Should -Contain 'StubsCreated'
        }

        It 'Result has TemplatesCopied property' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.PSObject.Properties.Name | Should -Contain 'TemplatesCopied'
        }

        It 'Result has DryRun property' {
            $result = & $scriptPath -Path $tempBase -RepoName 'test-repo'
            $result.PSObject.Properties.Name | Should -Contain 'DryRun'
        }
    }
}
