# Validation Scripts

This directory contains validation scripts used by the GitHub Actions workflow `.github/workflows/validate-plugin.yml` to ensure plugin quality.

## Scripts

### Test-FileStructure.ps1
Verifies required file structure by scanning `skills/` directories:
- `SKILL.md` exists in each skill directory
- `references/` directory has `.md` files (if present)
- `scripts/` directory has `.ps1` files (if present)

### Test-PowerShellSyntax.ps1
Parses all `.ps1` files to ensure they have valid PowerShell syntax.

### Test-SkillQuality.ps1
Validates `SKILL.md` quality requirements:
- Under 500 lines
- Has valid YAML frontmatter (enclosed in `---`)
- Frontmatter contains `name` and `description` fields

### Test-EvalCoverage.ps1
Verifies evaluation file coverage:
- Every capability has a corresponding `.eval.md` file
- Files follow naming pattern `NN-description.eval.md`

### Test-MarkdownStructure.ps1
Validates markdown structure of evaluation files:
- Has priority indicator (🔴, 🟡, 🟢)
- Has time estimate
- Has `## Objective` section
- Has `## Test Steps` or `## Setup` section

### Test-ScriptTestCoverage.ps1
Validates that all PowerShell scripts in skill directories have corresponding unit tests.

## Usage

All scripts accept a `-PluginPath` parameter (defaults to `omanfo`):

```powershell
# From repository root
pwsh -File ./omanfo/scripts/validation/Test-FileStructure.ps1 -PluginPath omanfo
```

Scripts exit with code 0 on success, non-zero on failure.

## CI/CD Integration

These scripts are automatically run by the GitHub Actions workflow when PRs modify files in `omanfo/**` or `okyeame/**` directories. All validations must pass before the PR can be merged.
