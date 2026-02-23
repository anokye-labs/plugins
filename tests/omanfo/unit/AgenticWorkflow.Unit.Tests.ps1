# AgenticWorkflow.Unit.Tests.ps1
# Pester 5 tests for the New-AgenticWorkflow.ps1 installer script

BeforeAll {
    $scriptPath     = Join-Path $PSScriptRoot "../../../scripts/New-AgenticWorkflow.ps1"
    $templatesDir   = Join-Path $PSScriptRoot "../../../workflow-templates/agentic"
}

Describe "New-AgenticWorkflow parameter validation" {
    It "Should have mandatory TemplateName parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "TemplateName"
        $cmd.Parameters['TemplateName'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have mandatory TargetRepoPath parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "TargetRepoPath"
        $cmd.Parameters['TargetRepoPath'].Attributes.Mandatory | Should -Be $true
    }

    It "Should have DryRun switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "DryRun"
    }
}

Describe "New-AgenticWorkflow template validation" {
    It "Should have template files for all supported template names" {
        $expected = @('issue-triage', 'stale-patrol', 'pr-health', 'issue-lifecycle', 'pr-triage')
        foreach ($name in $expected) {
            $file = Join-Path $templatesDir "$name.md"
            $file | Should -Exist
        }
    }

    It "Should reject an unknown template name" {
        $fakeTarget = (New-Item -ItemType Directory -Path (Join-Path $TestDrive "repo-unknown") -Force).FullName
        New-Item -ItemType Directory -Path (Join-Path $fakeTarget ".git") -Force | Out-Null

        { & $scriptPath -TemplateName "nonexistent-template" -TargetRepoPath $fakeTarget 2>&1 } |
            Should -Throw
    }

    It "Should return early when template name is invalid" {
        $fakeTarget = (New-Item -ItemType Directory -Path (Join-Path $TestDrive "repo-invalid") -Force).FullName
        New-Item -ItemType Directory -Path (Join-Path $fakeTarget ".git") -Force | Out-Null

        { & $scriptPath -TemplateName "bad-name" -TargetRepoPath $fakeTarget } |
            Should -Throw -ExpectedMessage "*Unknown template*"
    }
}

Describe "New-AgenticWorkflow target repo validation" {
    It "Should error when target path does not exist" {
        { & $scriptPath -TemplateName "issue-triage" -TargetRepoPath "/nonexistent/path/xyz" 2>&1 } |
            Should -Throw
    }

    It "Should error when target path is not a git repository" {
        $notARepo = (New-Item -ItemType Directory -Path (Join-Path $TestDrive "not-a-repo") -Force).FullName

        { & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $notARepo 2>&1 } |
            Should -Throw
    }
}

Describe "New-AgenticWorkflow DryRun mode" {
    BeforeAll {
        $fakeRepo = (New-Item -ItemType Directory -Path (Join-Path $TestDrive "fake-repo") -Force).FullName
        New-Item -ItemType Directory -Path (Join-Path $fakeRepo ".git") -Force | Out-Null
    }

    It "Should not copy files in DryRun mode" {
        & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $fakeRepo -DryRun *>&1

        $dest = Join-Path $fakeRepo ".github" "workflows" "issue-triage.md"
        $dest | Should -Not -Exist
    }

    It "Should not call gh aw compile in DryRun mode" {
        Mock gh { } -Verifiable

        & $scriptPath -TemplateName "stale-patrol" -TargetRepoPath $fakeRepo -DryRun *>&1

        Should -Not -Invoke gh
    }

    It "Should not call git in DryRun mode" {
        Mock git { } -Verifiable

        & $scriptPath -TemplateName "pr-health" -TargetRepoPath $fakeRepo -DryRun *>&1

        Should -Not -Invoke git
    }

    It "Should return a PSCustomObject in DryRun mode" {
        $result = & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $fakeRepo -DryRun

        $result | Should -BeOfType [PSCustomObject]
    }

    It "Should set DryRun property to true in result" {
        $result = & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $fakeRepo -DryRun

        $result.DryRun | Should -Be $true
    }

    It "Should set Installed to false in DryRun result" {
        $result = & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $fakeRepo -DryRun

        $result.Installed | Should -Be $false
    }

    It "Should include TemplateName in result" {
        $result = & $scriptPath -TemplateName "pr-triage" -TargetRepoPath $fakeRepo -DryRun

        $result.TemplateName | Should -Be "pr-triage"
    }

    It "Should include expected properties in result" {
        $result = & $scriptPath -TemplateName "issue-lifecycle" -TargetRepoPath $fakeRepo -DryRun

        $result.PSObject.Properties.Name | Should -Contain "TemplateName"
        $result.PSObject.Properties.Name | Should -Contain "TargetPath"
        $result.PSObject.Properties.Name | Should -Contain "LockPath"
        $result.PSObject.Properties.Name | Should -Contain "Installed"
        $result.PSObject.Properties.Name | Should -Contain "Compiled"
        $result.PSObject.Properties.Name | Should -Contain "Committed"
        $result.PSObject.Properties.Name | Should -Contain "DryRun"
    }

    It "Should output DryRun indicators in console output" {
        $output = & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $fakeRepo -DryRun *>&1

        $dryRunLines = $output | Where-Object { $_ -match '\[DryRun\]' }
        $dryRunLines.Count | Should -BeGreaterThan 0
    }
}

Describe "New-AgenticWorkflow install mode" {
    BeforeAll {
        $installRepo = (New-Item -ItemType Directory -Path (Join-Path $TestDrive "install-repo") -Force).FullName
        New-Item -ItemType Directory -Path (Join-Path $installRepo ".git") -Force | Out-Null
    }

    It "Should copy template .md file to target repo workflows directory" {
        Mock gh { $global:LASTEXITCODE = 0; return "" } `
            -ParameterFilter { $args[0] -eq 'aw' -and $args[1] -eq 'compile' }
        Mock git { $global:LASTEXITCODE = 0; return "" }

        & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $installRepo *>&1

        $dest = Join-Path $installRepo ".github" "workflows" "issue-triage.md"
        $dest | Should -Exist
    }

    It "Should call gh aw compile after copying" {
        Mock gh { $global:LASTEXITCODE = 0; return "" } `
            -ParameterFilter { $args[0] -eq 'aw' -and $args[1] -eq 'compile' } -Verifiable
        Mock git { $global:LASTEXITCODE = 0; return "" }

        & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $installRepo *>&1

        Should -Invoke gh -ParameterFilter { $args[0] -eq 'aw' -and $args[1] -eq 'compile' } -Times 1
    }

    It "Should call git add after compiling" {
        Mock gh { $global:LASTEXITCODE = 0; return "" } `
            -ParameterFilter { $args[0] -eq 'aw' -and $args[1] -eq 'compile' }
        Mock git { $global:LASTEXITCODE = 0; return "" } -Verifiable

        & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $installRepo *>&1

        Should -Invoke git -Times 1 -ParameterFilter { $args[0] -eq 'add' }
    }

    It "Should call git commit after adding" {
        Mock gh { $global:LASTEXITCODE = 0; return "" } `
            -ParameterFilter { $args[0] -eq 'aw' -and $args[1] -eq 'compile' }
        Mock git { $global:LASTEXITCODE = 0; return "" } -Verifiable

        & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $installRepo *>&1

        Should -Invoke git -Times 1 -ParameterFilter { $args[0] -eq 'commit' }
    }

    It "Should return PSCustomObject with Installed true" {
        Mock gh { $global:LASTEXITCODE = 0; return "" } `
            -ParameterFilter { $args[0] -eq 'aw' -and $args[1] -eq 'compile' }
        Mock git { $global:LASTEXITCODE = 0; return "" }

        $result = & $scriptPath -TemplateName "issue-triage" -TargetRepoPath $installRepo

        $result | Should -BeOfType [PSCustomObject]
        $result.Installed | Should -Be $true
        $result.DryRun | Should -Be $false
    }

    It "Should create .github/workflows directory if it does not exist" {
        $freshRepo = (New-Item -ItemType Directory -Path (Join-Path $TestDrive "fresh-repo") -Force).FullName
        New-Item -ItemType Directory -Path (Join-Path $freshRepo ".git") -Force | Out-Null

        Mock gh { $global:LASTEXITCODE = 0; return "" } `
            -ParameterFilter { $args[0] -eq 'aw' -and $args[1] -eq 'compile' }
        Mock git { $global:LASTEXITCODE = 0; return "" }

        & $scriptPath -TemplateName "stale-patrol" -TargetRepoPath $freshRepo *>&1

        $wfDir = Join-Path $freshRepo ".github" "workflows"
        $wfDir | Should -Exist
    }
}
