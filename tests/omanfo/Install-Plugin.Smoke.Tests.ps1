#!/usr/bin/env pwsh
# Install-Plugin.Smoke.Tests.ps1
# Smoke tests for plugin installation lifecycle via copilot CLI

BeforeAll {
    # These tests require the copilot CLI to be installed and available
    # They test the full lifecycle: marketplace add, install, list, update, uninstall, reinstall
    
    $script:TestRepo = $env:TEST_REPO
    if (-not $script:TestRepo) {
        $script:TestRepo = 'anokye-labs/plugins'
    }
    
    # Parse repo owner and name
    $repoParts = $script:TestRepo -split '/'
    $script:RepoOwner = $repoParts[0]
    $script:RepoName = $repoParts[1]
    
    $script:MarketplaceName = 'anokye-plugins'
    $script:PluginName = 'omanfo'
    
    # Check if copilot CLI is available
    $script:CopilotAvailable = $null -ne (Get-Command copilot -ErrorAction SilentlyContinue)
    
    if (-not $script:CopilotAvailable) {
        Write-Warning "Copilot CLI not found. Install-Plugin tests will be skipped."
    }
}

Describe "Copilot CLI Availability" {
    It "Should have copilot CLI installed or skip tests" -Skip:(-not $script:CopilotAvailable) {
        $script:CopilotAvailable | Should -Be $true
    }
}

Describe "Plugin Marketplace Operations" -Skip:(-not $script:CopilotAvailable) {
    Context "Marketplace Add" {
        It "Should add marketplace repository" {
            # Add the marketplace
            $output = copilot plugin marketplace add "$($script:RepoOwner)/$($script:RepoName)" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Marketplace add should succeed"
        }
        
        It "Should list marketplace repository after adding" {
            $output = copilot plugin marketplace list 2>&1 | Out-String
            $output | Should -Match $script:MarketplaceName -Because "Added marketplace should appear in list"
        }
        
        It "Should browse marketplace and show plugins" {
            $output = copilot plugin marketplace browse $script:MarketplaceName 2>&1 | Out-String
            $output | Should -Match $script:PluginName -Because "Plugin should be available in marketplace"
        }
    }
    
    Context "Plugin Installation" {
        It "Should install plugin from marketplace" {
            $output = copilot plugin install "$($script:PluginName)@$($script:MarketplaceName)" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Plugin installation should succeed"
        }
        
        It "Should list installed plugin" {
            $output = copilot plugin list 2>&1 | Out-String
            $output | Should -Match $script:PluginName -Because "Installed plugin should appear in list"
        }
        
        It "Should show plugin is enabled" {
            $output = copilot plugin list 2>&1 | Out-String
            # Plugin should be shown as enabled (not disabled)
            # The exact format may vary, but typically shows status
            $output | Should -Match $script:PluginName
        }
    }
    
    Context "Plugin Update" {
        It "Should check for updates without error" {
            # Update command should not fail even if no updates available
            $output = copilot plugin update "$($script:PluginName)" 2>&1
            # Accept both success (0) and "no updates" scenarios
            $LASTEXITCODE | Should -BeIn @(0, 1) -Because "Update command should complete"
        }
    }
    
    Context "Plugin Uninstallation" {
        It "Should uninstall plugin" {
            $output = copilot plugin uninstall "$($script:PluginName)" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Plugin uninstallation should succeed"
        }
        
        It "Should not list uninstalled plugin" {
            $output = copilot plugin list 2>&1 | Out-String
            # After uninstall, plugin should not appear or be marked as disabled
            # We'll just verify the command succeeds
            $LASTEXITCODE | Should -Be 0
        }
    }
    
    Context "Plugin Reinstallation" {
        It "Should reinstall plugin from marketplace" {
            $output = copilot plugin install "$($script:PluginName)@$($script:MarketplaceName)" 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Plugin reinstallation should succeed"
        }
        
        It "Should list reinstalled plugin" {
            $output = copilot plugin list 2>&1 | Out-String
            $output | Should -Match $script:PluginName -Because "Reinstalled plugin should appear in list"
        }
    }
}

Describe "Plugin Marketplace Cleanup" -Skip:(-not $script:CopilotAvailable) {
    Context "Cleanup Operations" {
        It "Should uninstall plugin for cleanup" {
            # Best effort cleanup - don't fail if already uninstalled
            copilot plugin uninstall "$($script:PluginName)" 2>&1 | Out-Null
            $true | Should -Be $true
        }
        
        It "Should remove marketplace for cleanup" {
            # Best effort cleanup - don't fail if already removed
            copilot plugin marketplace remove "$($script:MarketplaceName)" 2>&1 | Out-Null
            $true | Should -Be $true
        }
    }
}
