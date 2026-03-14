# ScriptSyntax.e2e.Tests.ps1
# Validates that all PowerShell scripts in the okyerema plugin parse without errors

BeforeAll {
    $pluginRoot = Join-Path $PSScriptRoot "../../../okyerema"
}

Describe "PowerShell Script Syntax Validation" {
    It "All .ps1 files in scripts/rhythm/ should parse" {
        $scripts = Get-ChildItem -Path (Join-Path $pluginRoot "scripts/rhythm") -Filter "*.ps1" -ErrorAction SilentlyContinue
        $scripts.Count | Should -BeGreaterThan 0

        foreach ($file in $scripts) {
            { [System.Management.Automation.ScriptBlock]::Create(
                (Get-Content $file.FullName -Raw)
            ) } | Should -Not -Throw -Because "$($file.Name) should have valid syntax"
        }
    }

    It "All .ps1 files in scripts/dispatch/ should parse" {
        $scripts = Get-ChildItem -Path (Join-Path $pluginRoot "scripts/dispatch") -Filter "*.ps1" -ErrorAction SilentlyContinue
        $scripts.Count | Should -BeGreaterThan 0

        foreach ($file in $scripts) {
            { [System.Management.Automation.ScriptBlock]::Create(
                (Get-Content $file.FullName -Raw)
            ) } | Should -Not -Throw -Because "$($file.Name) should have valid syntax"
        }
    }

    It "All .ps1 files in scripts/verify/ should parse" {
        $scripts = Get-ChildItem -Path (Join-Path $pluginRoot "scripts/verify") -Filter "*.ps1" -ErrorAction SilentlyContinue
        $scripts.Count | Should -BeGreaterThan 0

        foreach ($file in $scripts) {
            { [System.Management.Automation.ScriptBlock]::Create(
                (Get-Content $file.FullName -Raw)
            ) } | Should -Not -Throw -Because "$($file.Name) should have valid syntax"
        }
    }

    It "All .ps1 files in scripts/health/ should parse" {
        $scripts = Get-ChildItem -Path (Join-Path $pluginRoot "scripts/health") -Filter "*.ps1" -ErrorAction SilentlyContinue
        $scripts.Count | Should -BeGreaterThan 0

        foreach ($file in $scripts) {
            { [System.Management.Automation.ScriptBlock]::Create(
                (Get-Content $file.FullName -Raw)
            ) } | Should -Not -Throw -Because "$($file.Name) should have valid syntax"
        }
    }

    It "All .ps1 files in install/ should parse" {
        $scripts = Get-ChildItem -Path (Join-Path $pluginRoot "install") -Filter "*.ps1" -ErrorAction SilentlyContinue
        $scripts.Count | Should -BeGreaterThan 0

        foreach ($file in $scripts) {
            { [System.Management.Automation.ScriptBlock]::Create(
                (Get-Content $file.FullName -Raw)
            ) } | Should -Not -Throw -Because "$($file.Name) should have valid syntax"
        }
    }
}

Describe "Script Count Validation" {
    It "Should have 7 rhythm scripts" {
        $count = (Get-ChildItem -Path (Join-Path $pluginRoot "scripts/rhythm") -Filter "*.ps1").Count
        $count | Should -Be 7
    }

    It "Should have 10 dispatch scripts" {
        $count = (Get-ChildItem -Path (Join-Path $pluginRoot "scripts/dispatch") -Filter "*.ps1").Count
        $count | Should -Be 10
    }

    It "Should have 9 verify scripts" {
        $count = (Get-ChildItem -Path (Join-Path $pluginRoot "scripts/verify") -Filter "*.ps1").Count
        $count | Should -Be 9
    }

    It "Should have 5 health scripts" {
        $count = (Get-ChildItem -Path (Join-Path $pluginRoot "scripts/health") -Filter "*.ps1").Count
        $count | Should -Be 5
    }

    It "Should have 3 install scripts" {
        $count = (Get-ChildItem -Path (Join-Path $pluginRoot "install") -Filter "*.ps1").Count
        $count | Should -Be 3
    }
}
