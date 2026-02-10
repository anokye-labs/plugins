# Plugin Scripts

Repository-wide scripts for managing and validating plugins.

## Get-PluginCoverage.ps1

Generate coverage reports for plugin capabilities and evaluations.

### Synopsis

Reads `manifest.json` to identify declared capabilities (scripts and evaluations), scans the plugin directory structure to find actual scripts and evaluation files, and reports on coverage status.

### Usage

```powershell
# Basic usage - defaults to omanfo plugin
./scripts/Get-PluginCoverage.ps1

# Specify plugin path
./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo

# JSON output only
./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo -OutputFormat json

# Text output only
./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo -OutputFormat text

# Both JSON and text output (default)
./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo -OutputFormat both

# Set minimum coverage threshold (0-100%)
./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo -MinimumCoverage 80
```

### Parameters

- **PluginPath** - Path to the plugin directory. Defaults to `omanfo` relative to repository root.
- **OutputFormat** - Output format: `json`, `text`, or `both`. Defaults to `both`.
- **MinimumCoverage** - Minimum coverage percentage required (0-100). Defaults to 100.
  - When set to **100** (default): Enforces strict mode requiring exact count match (actual ≥ declared) AND 100% coverage
  - When set to **< 100**: Uses percentage-based validation only, allowing gradual coverage improvement

### Exit Codes

- **0** - Coverage meets or exceeds requirements
- **1** - Coverage is incomplete or below minimum threshold

### Output

#### Text Format

Human-readable report with:
- Plugin name and version
- Script coverage (declared vs actual)
- Evaluation coverage (declared vs actual)
- Overall coverage percentage
- List of found files
- Status indicators (✓ PASS / ✗ FAIL)

#### JSON Format

Structured JSON report with:
```json
{
  "Plugin": "omanfo",
  "Version": "1.0.0",
  "Timestamp": "2026-02-10T02:50:23Z",
  "Scripts": {
    "Declared": 10,
    "Actual": 10,
    "Coverage": 100.0,
    "Status": "✓ PASS",
    "Files": ["..."]
  },
  "Evaluations": {
    "Declared": 8,
    "Actual": 8,
    "Coverage": 100.0,
    "Status": "✓ PASS",
    "Files": ["..."]
  },
  "Overall": {
    "Coverage": 100.0,
    "MinimumRequired": 100,
    "Status": "✓ PASS"
  }
}
```

### Examples

Check omanfo plugin coverage:
```powershell
./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo
```

Generate JSON report for CI:
```powershell
./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo -OutputFormat json > coverage.json
```

Validate with 80% minimum coverage:
```powershell
./scripts/Get-PluginCoverage.ps1 -PluginPath ./omanfo -MinimumCoverage 80
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Coverage check passed"
} else {
    Write-Host "✗ Coverage check failed"
    exit 1
}
```

### Requirements

- PowerShell 7.0+
- Valid `manifest.json` in plugin directory
- Plugin must follow standard structure:
  - Scripts: `{plugin}/.github/skills/{skill}/scripts/*.ps1`
  - Evaluations: `{plugin}/evaluations/*.eval.md`

### Integration

This script can be used in:
- CI/CD pipelines to enforce coverage requirements
- Pre-commit hooks to validate changes
- Manual validation during development
- Automated reports for plugin status

### Related

- [omanfo/evaluations/README.md](../omanfo/evaluations/README.md) - Evaluation scenarios
- [omanfo/manifest.json](../omanfo/manifest.json) - Plugin manifest structure
