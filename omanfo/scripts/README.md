# Omanfo Scripts

Deployment, validation, and automation scripts for the Omanfo plugin.

## Contents

| Item | Purpose |
|------|---------|
| `Install-Anokye.ps1` | Deploy Omanfo files (docs, agents.md) to a target repository |
| `Verify-Installation.ps1` | Validate that installation completed correctly |
| [pr-automation/](pr-automation/) | PR automation helper scripts |
| [validation/](validation/) | Plugin quality validation scripts (used by CI) |

## Usage

```powershell
# Deploy to a target repo
./omanfo/scripts/Install-Anokye.ps1 -TargetRepo /path/to/repo

# Run validation
pwsh -File ./omanfo/scripts/validation/Test-FileStructure.ps1 -PluginPath omanfo
```
