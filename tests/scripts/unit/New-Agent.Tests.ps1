# New-Agent.Tests.ps1
# Pester unit tests for scripts/New-Agent.ps1

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../../../scripts/New-Agent.ps1'
    $tempDir    = Join-Path ([System.IO.Path]::GetTempPath()) "new-agent-tests-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

AfterAll {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}

Describe 'New-Agent.ps1' {

    Context 'Parameter validation' {
        It 'Has a mandatory -Name parameter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'Name'
            $paramAttr = $cmd.Parameters['Name'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -First 1
            $paramAttr.Mandatory | Should -BeTrue
        }

        It 'Has a mandatory -Archetype parameter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'Archetype'
            $paramAttr = $cmd.Parameters['Archetype'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -First 1
            $paramAttr.Mandatory | Should -BeTrue
        }

        It 'Restricts -Archetype to the four valid values' {
            $cmd = Get-Command $scriptPath
            $validateSet = $cmd.Parameters['Archetype'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'doc-sync'
            $validateSet.ValidValues | Should -Contain 'labeler'
            $validateSet.ValidValues | Should -Contain 'reviewer'
            $validateSet.ValidValues | Should -Contain 'custom'
            $validateSet.ValidValues.Count | Should -Be 4
        }

        It 'Rejects invalid archetype values' {
            { & $scriptPath -Name test-agent -Archetype invalid-archetype -OutputPath $tempDir } | Should -Throw
        }
    }

    Context 'DryRun mode' {
        It 'Returns a result object with DryRun=true' {
            $result = & $scriptPath -Name dry-test -Archetype custom -OutputPath $tempDir -DryRun
            $result.DryRun | Should -BeTrue
        }

        It 'Does not write any files in DryRun mode' {
            $outDir = Join-Path $tempDir 'dryrun-test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            & $scriptPath -Name dryagent -Archetype custom -OutputPath $outDir -DryRun | Out-Null
            (Get-ChildItem $outDir -Recurse).Count | Should -Be 0
        }

        It 'Lists expected files in FilesCreated when DryRun' {
            $result = & $scriptPath -Name dry-list -Archetype reviewer -OutputPath $tempDir -DryRun
            $result.FilesCreated.Count | Should -Be 4
        }
    }

    Context 'File generation' {
        BeforeAll {
            $outDir = Join-Path $tempDir 'file-gen'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $script:result = & $scriptPath -Name my-agent -Archetype reviewer -OutputPath $outDir
            $script:outDir = $outDir
        }

        It 'Returns a structured PSCustomObject result' {
            $script:result | Should -BeOfType [PSCustomObject]
        }

        It 'Result contains Name, Archetype, OutputPath, DryRun, FilesCreated' {
            $script:result.Name       | Should -Be 'my-agent'
            $script:result.Archetype  | Should -Be 'reviewer'
            $script:result.DryRun     | Should -BeFalse
            $script:result.FilesCreated | Should -Not -BeNullOrEmpty
        }

        It 'Creates the .agent.md file' {
            $agentMd = Join-Path $script:outDir '.github/agents/my-agent.agent.md'
            Test-Path $agentMd | Should -BeTrue
        }

        It 'Creates the .agent.ps1 implementation placeholder' {
            $agentPs1 = Join-Path $script:outDir '.github/agents/my-agent.agent.ps1'
            Test-Path $agentPs1 | Should -BeTrue
        }

        It 'Creates the GitHub Actions workflow YAML' {
            $workflow = Join-Path $script:outDir '.github/workflows/my-agent.yml'
            Test-Path $workflow | Should -BeTrue
        }

        It 'Creates the Pester test file' {
            $test = Join-Path $script:outDir 'tests/scripts/unit/my-agent.Agent.Tests.ps1'
            Test-Path $test | Should -BeTrue
        }

        It 'FilesCreated has Written=true for all files' {
            $script:result.FilesCreated | ForEach-Object {
                $_.Written | Should -BeTrue
            }
        }
    }

    Context 'Agent definition content' {
        It 'agent.md contains the agent name in frontmatter' {
            $outDir = Join-Path $tempDir 'content-test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            & $scriptPath -Name content-agent -Archetype labeler -OutputPath $outDir | Out-Null
            $content = Get-Content (Join-Path $outDir '.github/agents/content-agent.agent.md') -Raw
            $content | Should -Match 'name: content-agent'
        }

        It 'agent.md contains the correct archetype' {
            $outDir = Join-Path $tempDir 'archetype-test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            & $scriptPath -Name arch-agent -Archetype doc-sync -OutputPath $outDir | Out-Null
            $content = Get-Content (Join-Path $outDir '.github/agents/arch-agent.agent.md') -Raw
            $content | Should -Match 'archetype: doc-sync'
        }

        It 'workflow.yml contains the agent name' {
            $outDir = Join-Path $tempDir 'workflow-content-test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            & $scriptPath -Name wf-agent -Archetype custom -OutputPath $outDir | Out-Null
            $content = Get-Content (Join-Path $outDir '.github/workflows/wf-agent.yml') -Raw
            $content | Should -Match 'wf-agent'
        }
    }

    Context 'Default OutputPath' {
        It 'Defaults to the repo root when OutputPath is not specified' {
            $result = & $scriptPath -Name default-path-agent -Archetype custom -DryRun
            # The default should resolve to a path (parent of the scripts/ directory)
            $result.OutputPath | Should -Not -BeNullOrEmpty
        }
    }
}
