# Plugin Validation Scripts

This directory contains validation scripts used by the CI pipeline to ensure plugin quality and coverage.

## Scripts

### Test-ManifestConsistency.ps1

Validates that `manifest.json` is consistent with actual plugin files.

**Checks:**
- Script count matches actual `.ps1` files in skill scripts directory
- Reference count matches actual `.md` files in references directory
- Evaluation count matches actual `.eval.md` files
- All required manifest fields are present
- Entry point file exists

**Usage:**
```powershell
.\Test-ManifestConsistency.ps1
```

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more checks failed

---

### Validate-PluginInstall.ps1

Tests that the plugin installs correctly into a test repository.

**Checks:**
- Installation completes without errors
- All expected files are present after installation
- SKILL.md has valid YAML frontmatter
- PowerShell scripts have no syntax errors
- manifest.json is valid JSON
- Required manifest fields are present

**Usage:**
```powershell
.\Validate-PluginInstall.ps1
```

**Exit Codes:**
- `0` - Installation validation passed
- `1` - Installation validation failed

**Note:** Creates a temporary test repository in the system temp directory, which is automatically cleaned up.

---

### Test-PluginCoverage.ps1

Enforces plugin coverage - ensures every feature has validation tests and evaluations.

**Coverage Matrix:**
- Maps skill scripts to features
- Maps evaluation files to features
- Calculates coverage percentage
- Identifies features without evaluations

**Parameters:**
- `-MinimumCoverage` - Minimum coverage percentage required (default: 80)

**Usage:**
```powershell
.\Test-PluginCoverage.ps1
.\Test-PluginCoverage.ps1 -MinimumCoverage 100
```

**Exit Codes:**
- `0` - Coverage meets minimum threshold
- `1` - Coverage below threshold or validation failed

**Feature Mapping:**

Scripts are mapped to features based on naming patterns:
- `*IssueType*` → `issue-types`
- `*Hierarchy*`, `*SubIssue*`, `*Parent*` → `hierarchy`
- `*Project*` → `projects`
- `*PR*`, `*Review*`, `*Thread*` → `pr-reviews`
- `*Label*` → `labels`
- `*Sitrep*`, `*Health*` → `end-to-end`
- `New-IssueWithType` → `create-issues`

Evaluations are mapped by filename: `NN-feature-name.eval.md` → `feature-name`

---

### Invoke-EvalScenarios.ps1

Runs automated checks from `.eval.md` evaluation files.

**Automated Checks:**
- File existence validation
- Script syntax validation
- Required references present

**Parameters:**
- `-EvalPath` - Path to specific evaluation file (optional, runs all if omitted)
- `-GenerateChecklist` - Generate human verification checklist for manual scenarios

**Usage:**
```powershell
.\Invoke-EvalScenarios.ps1
.\Invoke-EvalScenarios.ps1 -EvalPath "01-install-verify.eval.md"
.\Invoke-EvalScenarios.ps1 -GenerateChecklist
```

**Exit Codes:**
- `0` - All automated checks passed
- `1` - One or more checks failed

**Evaluation Coverage:**
- `install-verify` - Installation and file structure
- `issue-types` - Organization issue type discovery
- `create-issues` - Creating typed issues
- `hierarchy` - Building parent-child relationships
- `projects` - GitHub Projects V2 integration
- `pr-reviews` - PR review thread management
- `labels` - Label operations
- `end-to-end` - Full workflow (partial automation)

---

### New-CoverageReport.ps1

Generates a comprehensive coverage report in markdown format.

**Report Sections:**
- Executive summary with coverage statistics
- Coverage status (Pass/Warning/Fail)
- Feature coverage matrix
- Detailed feature breakdown
- Recommendations for uncovered features
- Manifest summary

**Parameters:**
- `-OutputPath` - Path where report should be saved (default: `coverage-report.md` in repo root)

**Usage:**
```powershell
.\New-CoverageReport.ps1
.\New-CoverageReport.ps1 -OutputPath ./reports/coverage.md
```

**Exit Codes:** Always exits 0 (report is informational)

**Coverage Thresholds:**
- ✅ **80-100%** - Pass (green)
- ⚠️ **60-79%** - Warning (yellow)
- ❌ **0-59%** - Fail (red)

---

## CI Integration

These scripts are run automatically by the GitHub Actions workflow `.github/workflows/validate-plugin.yml` on:
- Pull requests modifying `omanfo/**` or `okyeame/**`
- Pushes to `main` branch

### Workflow Steps

1. **Validate Manifest Consistency** - Ensures manifest.json is accurate
2. **Test Plugin Installation** - Verifies plugin installs correctly
3. **Validate Plugin Coverage** - Enforces 80% minimum coverage
4. **Run Evaluation Scenarios** - Executes automated evaluation checks
5. **Generate Coverage Report** - Creates coverage artifact

### Artifacts

The workflow uploads a `coverage-report.md` artifact that persists for 30 days. Download it from the workflow run to see detailed coverage statistics.

---

## Local Testing

You can run these validation scripts locally before pushing:

```powershell
# Run all validations
cd /path/to/plugins
pwsh -File ./omanfo/scripts/validation/Test-ManifestConsistency.ps1
pwsh -File ./omanfo/scripts/validation/Validate-PluginInstall.ps1
pwsh -File ./omanfo/scripts/validation/Test-PluginCoverage.ps1
pwsh -File ./omanfo/scripts/validation/Invoke-EvalScenarios.ps1
pwsh -File ./omanfo/scripts/validation/New-CoverageReport.ps1
```

---

## Adding New Features

When adding a new feature to the plugin:

1. **Add the script(s)** to `.github/skills/okyerema/scripts/`
2. **Create an evaluation** in `evaluations/` following the naming pattern `NN-feature-name.eval.md`
3. **Update manifest.json** if script/reference counts change
4. **Run coverage validation** to ensure 100% coverage is maintained

### Coverage Enforcement

The CI pipeline will **fail** if:
- A new script is added without a corresponding evaluation
- Coverage drops below 80%
- manifest.json is inconsistent with actual files
- Plugin installation fails

This ensures that all features are properly validated and documented.

---

## Troubleshooting

### "manifest.json validation failed"
- Check that script/reference/evaluation counts in manifest match actual files
- Ensure all required fields are present in manifest
- Verify SKILL.md exists at declared path

### "Plugin installation validation failed"
- Check PowerShell syntax errors in scripts
- Verify YAML frontmatter in SKILL.md is valid
- Ensure Install-Plugin.ps1 completes successfully

### "Coverage below threshold"
- Add evaluation files for uncovered features
- Ensure evaluation files follow naming pattern: `NN-feature-name.eval.md`
- Check feature mapping in Test-PluginCoverage.ps1 script

### "Evaluation checks failed"
- Verify required scripts exist
- Verify required reference files exist
- Check script syntax is valid

---

## Requirements

- **PowerShell 7.0+**
- **Git** (for installation validation)
- **GitHub CLI** (for evaluation scenarios that use GitHub API)

---

## Exit Codes Summary

All validation scripts follow the convention:
- `0` = Success / Pass
- `1` = Failure / Validation error

This allows the CI pipeline to fail fast when issues are detected.
