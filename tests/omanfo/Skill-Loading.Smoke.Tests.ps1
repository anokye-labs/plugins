#!/usr/bin/env pwsh
# Skill-Loading.Smoke.Tests.ps1
# Smoke tests for skill discovery and slash command recognition

BeforeAll {
    # Get the plugin root directory
    # From tests/omanfo/ we need to go up to repo root, then to omanfo/
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:PluginRoot = Join-Path $repoRoot "omanfo"
    $script:SkillsPath = Join-Path $script:PluginRoot ".github/skills"
    
    # Expected skills from marketplace.json
    $script:ExpectedSkills = @(
        'okyerema',
        'doc-coauthoring',
        'docx',
        'github-issue-creator',
        'internal-comms',
        'okyeame',
        'pdf',
        'pptx',
        'product-management',
        'productivity',
        'skill-creator',
        'xlsx'
    )
    
    # Expected slash commands from okyeame skill
    $script:ExpectedSlashCommands = @(
        '/sitrep',
        '/context',
        '/prcheck',
        '/whatsleft',
        '/recap',
        '/health',
        '/board',
        '/watch'
    )
}

Describe "Plugin Directory Structure" {
    It "Should have .github/skills directory" {
        Test-Path $script:SkillsPath | Should -Be $true
    }
    
    It "Should have okyerema skill directory" {
        $okyeremaPath = Join-Path $script:SkillsPath "okyerema"
        Test-Path $okyeremaPath | Should -Be $true
    }
    
    It "Should have okyeame skill directory" {
        $okyeamePath = Join-Path $script:SkillsPath "okyeame"
        Test-Path $okyeamePath | Should -Be $true
    }
}

Describe "Skill Discovery" {
    Context "All Expected Skills" {
        It "Should have all expected skill directories" {
            $actualSkills = Get-ChildItem -Path $script:SkillsPath -Directory | Select-Object -ExpandProperty Name
            
            foreach ($expectedSkill in $script:ExpectedSkills) {
                $actualSkills | Should -Contain $expectedSkill -Because "Skill '$expectedSkill' should be present"
            }
        }
    }
    
    Context "Skill Structure" {
        It "Should have SKILL.md in okyerema" {
            $skillMd = Join-Path $script:SkillsPath "okyerema/SKILL.md"
            Test-Path $skillMd | Should -Be $true
        }
        
        It "Should have SKILL.md in okyeame" {
            $skillMd = Join-Path $script:SkillsPath "okyeame/SKILL.md"
            Test-Path $skillMd | Should -Be $true
        }
        
        It "Should have scripts directory in okyerema" {
            $scriptsDir = Join-Path $script:SkillsPath "okyerema/scripts"
            Test-Path $scriptsDir | Should -Be $true
        }
        
        It "Should have PowerShell scripts in okyerema" {
            $scriptsDir = Join-Path $script:SkillsPath "okyerema/scripts"
            $scripts = Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -File
            $scripts.Count | Should -BeGreaterThan 0 -Because "okyerema should have PowerShell scripts"
        }
    }
}

Describe "Slash Command Recognition" {
    Context "Okyeame Slash Commands" {
        BeforeAll {
            $script:OkyeameSkillContent = Get-Content (Join-Path $script:SkillsPath "okyeame/SKILL.md") -Raw
        }
        
        It "Should document slash commands in okyeame SKILL.md" {
            $script:OkyeameSkillContent | Should -Not -BeNullOrEmpty
        }
        
        It "Should document /sitrep command" {
            $script:OkyeameSkillContent | Should -Match '/sitrep' -Because "/sitrep command should be documented"
        }
        
        It "Should document /context command" {
            $script:OkyeameSkillContent | Should -Match '/context' -Because "/context command should be documented"
        }
        
        It "Should document /prcheck command" {
            $script:OkyeameSkillContent | Should -Match '/prcheck' -Because "/prcheck command should be documented"
        }
        
        It "Should document /whatsleft command" {
            $script:OkyeameSkillContent | Should -Match '/whatsleft' -Because "/whatsleft command should be documented"
        }
        
        It "Should document /recap command" {
            $script:OkyeameSkillContent | Should -Match '/recap' -Because "/recap command should be documented"
        }
        
        It "Should document /health command" {
            $script:OkyeameSkillContent | Should -Match '/health' -Because "/health command should be documented"
        }
        
        It "Should document all expected slash commands" {
            foreach ($command in $script:ExpectedSlashCommands) {
                $escapedCommand = [regex]::Escape($command)
                $script:OkyeameSkillContent | Should -Match $escapedCommand -Because "$command should be documented"
            }
        }
    }
    
    Context "Supporting Scripts" {
        It "Should have Get-Sitrep.ps1 script for /sitrep" {
            $scriptPath = Join-Path $script:SkillsPath "okyerema/scripts/Get-Sitrep.ps1"
            Test-Path $scriptPath | Should -Be $true -Because "/sitrep should have supporting script"
        }
        
        It "Should have Get-PRHealth.ps1 script for /prcheck" {
            $scriptPath = Join-Path $script:SkillsPath "okyerema/scripts/Get-PRHealth.ps1"
            Test-Path $scriptPath | Should -Be $true -Because "/prcheck should have supporting script"
        }
        
        It "Should have Get-HierarchyHealth.ps1 script for /health" {
            $scriptPath = Join-Path $script:SkillsPath "okyerema/scripts/Get-HierarchyHealth.ps1"
            Test-Path $scriptPath | Should -Be $true -Because "/health should have supporting script"
        }
    }
}

Describe "Skill Metadata" {
    Context "Okyerema Skill" {
        BeforeAll {
            $script:OkyeremaSkillContent = Get-Content (Join-Path $script:SkillsPath "okyerema/SKILL.md") -Raw
        }
        
        It "Should have frontmatter with name" {
            $script:OkyeremaSkillContent | Should -Match 'name:\s*okyerema'
        }
        
        It "Should have frontmatter with description" {
            $script:OkyeremaSkillContent | Should -Match 'description:'
        }
        
        It "Should describe project orchestration" {
            $script:OkyeremaSkillContent | Should -Match '(orchestration|GitHub|issue)' -Because "Should describe its purpose"
        }
    }
    
    Context "Okyeame Skill" {
        BeforeAll {
            $script:OkyeameSkillContent = Get-Content (Join-Path $script:SkillsPath "okyeame/SKILL.md") -Raw
        }
        
        It "Should have frontmatter with name" {
            $script:OkyeameSkillContent | Should -Match 'name:\s*okyeame'
        }
        
        It "Should have frontmatter with description" {
            $script:OkyeameSkillContent | Should -Match 'description:'
        }
        
        It "Should describe status reporting" {
            $script:OkyeameSkillContent | Should -Match '(status|linguist|voice)' -Because "Should describe its purpose"
        }
    }
}

Describe "Plugin Manifest Validation" {
    Context "Manifest File" {
        BeforeAll {
            $script:ManifestPath = Join-Path $script:PluginRoot "manifest.json"
            $script:Manifest = Get-Content $script:ManifestPath -Raw | ConvertFrom-Json
        }
        
        It "Should have manifest.json in plugin root" {
            Test-Path $script:ManifestPath | Should -Be $true
        }
        
        It "Should have valid JSON format" {
            $script:Manifest | Should -Not -BeNullOrEmpty
        }
        
        It "Should have name field" {
            $script:Manifest.name | Should -Be 'omanfo'
        }
        
        It "Should have version field" {
            $script:Manifest.version | Should -Not -BeNullOrEmpty
        }
        
        It "Should have skills array" {
            $script:Manifest.skills | Should -Not -BeNullOrEmpty
            $script:Manifest.skills.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Agent Configuration Files" {
    Context "Agent Markdown Files" {
        It "Should have okyeame.agent.md in plugin root" {
            $agentMd = Join-Path $script:PluginRoot "okyeame.agent.md"
            Test-Path $agentMd | Should -Be $true
        }
        
        It "Should have okyerema agent.md in skill directory" {
            $agentMd = Join-Path $script:SkillsPath "okyerema/okyerema.agent.md"
            Test-Path $agentMd | Should -Be $true
        }
    }
}
