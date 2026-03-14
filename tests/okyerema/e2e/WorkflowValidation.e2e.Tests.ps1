# WorkflowValidation.e2e.Tests.ps1
# Validates YAML workflow templates and JSON manifests

BeforeAll {
    $pluginRoot = Join-Path $PSScriptRoot "../../../okyerema"
}

Describe "Workflow Template Validation" {
    It "All YAML files should be valid" {
        $yamlFiles = Get-ChildItem -Path (Join-Path $pluginRoot "workflows") -Filter "*.yml" -ErrorAction SilentlyContinue

        $yamlFiles.Count | Should -BeGreaterThan 0

        foreach ($file in $yamlFiles) {
            # Basic YAML structure check — ensure it starts with a recognized key
            $content = Get-Content $file.FullName -Raw
            $content | Should -Match "^name:" -Because "$($file.Name) should have a name field"
        }
    }

    It "All workflow files should have 'on' trigger" {
        $yamlFiles = Get-ChildItem -Path (Join-Path $pluginRoot "workflows") -Filter "*.yml"

        foreach ($file in $yamlFiles) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -Match "\non:" -Because "$($file.Name) should have an 'on' trigger"
        }
    }

    It "All workflow files should have at least one job" {
        $yamlFiles = Get-ChildItem -Path (Join-Path $pluginRoot "workflows") -Filter "*.yml"

        foreach ($file in $yamlFiles) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -Match "\njobs:" -Because "$($file.Name) should have a jobs section"
        }
    }
}

Describe "Plugin Manifest Validation" {
    It "plugin.json should be valid JSON" {
        $manifestPath = Join-Path $pluginRoot ".github/plugin/plugin.json"
        Test-Path $manifestPath | Should -BeTrue

        $content = Get-Content $manifestPath -Raw
        { $content | ConvertFrom-Json } | Should -Not -Throw
    }

    It "plugin.json items should reference existing files" {
        $manifestPath = Join-Path $pluginRoot ".github/plugin/plugin.json"
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

        foreach ($item in $manifest.items) {
            $itemPath = Join-Path $pluginRoot $item.path
            Test-Path $itemPath | Should -BeTrue -Because "Item path '$($item.path)' should exist"
        }
    }

    It "plugin.json should have required fields" {
        $manifestPath = Join-Path $pluginRoot ".github/plugin/plugin.json"
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

        $manifest.name | Should -Not -BeNullOrEmpty
        $manifest.description | Should -Not -BeNullOrEmpty
        $manifest.version | Should -Not -BeNullOrEmpty
        $manifest.items | Should -Not -BeNullOrEmpty
    }
}
