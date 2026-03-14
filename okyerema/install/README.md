# Okyerema Install Scripts

Deployment scripts for installing the Okyerema plugin into target repositories.

## Scripts

| Script | Purpose |
|--------|---------|
| `Install-Okyerema.ps1` | Deploy Okyerema workflows, scripts, and skill files to a target repo |
| `Install-ClaudeCode.ps1` | Configure Claude Code integration for the Okyerema plugin |
| `Verify-Installation.ps1` | Validate that installation completed correctly |

## Usage

```powershell
# Install Okyerema into a target repository
./okyerema/install/Install-Okyerema.ps1 -TargetRepo /path/to/repo

# Verify installation
./okyerema/install/Verify-Installation.ps1 -TargetRepo /path/to/repo
```
