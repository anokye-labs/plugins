# CI Troubleshooting Guide

This guide helps you diagnose and fix common CI validation failures in the plugin repository.

## Quick Diagnosis

When a CI workflow fails, check the workflow run logs for the specific validation step that failed:

1. Go to the PR or commit in GitHub
2. Click **Details** next to the failed check
3. Identify which validation step failed
4. Follow the relevant section below

---

## Manifest Consistency Failures

### Error: "Script count: declared=X, actual=Y"

**Cause:** The number of scripts declared in `manifest.json` doesn't match the actual `.ps1` files in `.github/skills/okyerema/scripts/`.

**Fix:**
```powershell
# Count actual scripts
$actualCount = (Get-ChildItem ./omanfo/.github/skills/okyerema/scripts -Filter "*.ps1").Count

# Update manifest.json
# Change "scripts": OLD_NUMBER to "scripts": $actualCount
```

### Error: "Reference count: declared=X, actual=Y"

**Cause:** The number of references declared in `manifest.json` doesn't match actual `.md` files in `.github/skills/okyerema/references/`.

**Fix:**
```powershell
# Count actual references
$actualCount = (Get-ChildItem ./omanfo/.github/skills/okyerema/references -Filter "*.md").Count

# Update manifest.json
# Change "references": OLD_NUMBER to "references": $actualCount
```

### Error: "Evaluation count: declared=X, actual=Y"

**Cause:** The number of evaluations in `manifest.json` doesn't match actual `.eval.md` files.

**Fix:**
```powershell
# Count actual evaluations
$actualCount = (Get-ChildItem ./omanfo/evaluations -Filter "*.eval.md").Count

# Update manifest.json
# Change "count": OLD_NUMBER to "count": $actualCount
```

### Error: "Field 'X' is present"

**Cause:** A required field is missing or empty in `manifest.json`.

**Fix:**
Ensure these fields are present and non-empty:
- `name`
- `version`
- `description`
- `skill.name`
- `skill.path`
- `skill.entryPoint`

---

## Plugin Installation Failures

### Error: "Installation completed successfully" (False)

**Cause:** The `Install-Plugin.ps1` script failed during execution.

**Fix:**
1. Test installation locally:
   ```powershell
   $testRepo = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "test-install")
   cd $testRepo
   git init
   & /path/to/Install-Plugin.ps1 -TargetRepo . -Force
   ```
2. Check for PowerShell syntax errors
3. Verify all source files exist
4. Check for permission issues

### Error: "SKILL.md has valid YAML frontmatter"

**Cause:** The SKILL.md file is missing YAML frontmatter or it's malformed.

**Expected format:**
```yaml
---
name: okyerema
description: >
  Your description here
---

# Rest of file
```

**Fix:**
1. Check that frontmatter starts with `---` on line 1
2. Ensure frontmatter ends with `---`
3. Validate YAML syntax (no tabs, proper indentation)

### Error: "Script 'X.ps1' has no syntax errors"

**Cause:** PowerShell syntax error in a script file.

**Fix:**
```powershell
# Check syntax
$errors = $null
[System.Management.Automation.PSParser]::Tokenize(
    (Get-Content ./path/to/script.ps1 -Raw),
    [ref]$errors
)
$errors  # Shows syntax errors
```

---

## Coverage Validation Failures

### Error: "Coverage is X%, required Y%"

**Cause:** Plugin feature coverage is below the minimum threshold (default 80%).

**Fix:**
1. Run coverage validation locally:
   ```powershell
   pwsh -File ./omanfo/scripts/validation/Test-PluginCoverage.ps1
   ```
2. Check the output for features marked with ❌
3. For each uncovered feature, create a corresponding evaluation file

### Adding a New Evaluation

When a feature lacks an evaluation:

1. **Identify the feature name** from coverage report
2. **Create evaluation file** following naming pattern:
   ```
   evaluations/NN-feature-name.eval.md
   ```
   - Use next sequential number (NN)
   - Use kebab-case for feature name
   - Must end with `.eval.md`

3. **Use this template:**
   ```markdown
   # Evaluation NN: Feature Name
   
   **Priority:** 🔴 Critical / 🟡 Important / 🟢 Nice-to-have
   **Time:** X minutes
   **Prerequisites:** List any requirements
   
   ## Objective
   
   What this evaluation tests.
   
   ## Test Steps
   
   ### N.1 Test Name
   
   **Action:** What to do.
   
   **Expected:**
   - [ ] Specific expected outcome
   - [ ] Another expected outcome
   ```

4. **Update manifest.json** evaluation count
5. **Re-run coverage validation**

### Error: "All scripts are mapped to features"

**Cause:** A script exists that isn't mapped to any feature.

**Fix:**
This is usually a false positive. Check the feature mapping in `Test-PluginCoverage.ps1`:
- Does the script name match a pattern?
- Should a new pattern be added?
- Should the script be renamed?

---

## Evaluation Scenario Failures

### Error: "Script 'X.ps1' exists"

**Cause:** An evaluation references a script that doesn't exist.

**Fix:**
1. Verify the script exists: `ls ./omanfo/.github/skills/okyerema/scripts/`
2. Check the script name matches exactly (case-sensitive on Linux)
3. If script was renamed, update evaluation documentation

### Error: "Reference 'X.md' exists"

**Cause:** An evaluation references a reference file that doesn't exist.

**Fix:**
1. Verify the reference exists: `ls ./omanfo/.github/skills/okyerema/references/`
2. Check the reference name matches exactly
3. If reference was removed, update the evaluation

---

## GitHub Actions Workflow Failures

### Error: "Unable to resolve action"

**Cause:** GitHub Actions workflow references an action that doesn't exist or has the wrong version.

**Fix:**
1. Check workflow file: `.github/workflows/validate-plugin.yml`
2. Verify action names and versions
3. Common actions:
   - `actions/checkout@v4`
   - `actions/upload-artifact@v4`

### Error: "PowerShell command not found"

**Cause:** PowerShell 7+ is not available in the runner environment.

**Fix:**
The workflow uses `ubuntu-latest` which includes PowerShell 7. If this fails:
1. Check the `runs-on` field in workflow
2. Verify `shell: pwsh` is set correctly
3. Check for typos in script paths

### Error: "Permission denied"

**Cause:** Script doesn't have execute permissions or file access issue.

**Fix:**
```bash
# On Linux/Mac, ensure scripts are readable
chmod +r ./omanfo/scripts/validation/*.ps1
```

PowerShell scripts don't need execute bits, just read access.

---

## Testing Locally

Before pushing, run all validations locally:

```powershell
# Navigate to repo root
cd /path/to/plugins

# Run each validation
pwsh -File ./omanfo/scripts/validation/Test-ManifestConsistency.ps1
pwsh -File ./omanfo/scripts/validation/Validate-PluginInstall.ps1
pwsh -File ./omanfo/scripts/validation/Test-PluginCoverage.ps1
pwsh -File ./omanfo/scripts/validation/Invoke-EvalScenarios.ps1

# Generate coverage report
pwsh -File ./omanfo/scripts/validation/New-CoverageReport.ps1
cat coverage-report.md
```

All scripts should exit with code `0` for success.

---

## Common Scenarios

### Scenario: Adding a new script

1. Create the script in `.github/skills/okyerema/scripts/`
2. Update `manifest.json` script count
3. Create or update evaluation file
4. Test locally:
   ```powershell
   pwsh -File ./omanfo/scripts/validation/Test-ManifestConsistency.ps1
   pwsh -File ./omanfo/scripts/validation/Test-PluginCoverage.ps1
   ```

### Scenario: Adding a new reference

1. Create the reference in `.github/skills/okyerema/references/`
2. Update `manifest.json` reference count
3. Test locally:
   ```powershell
   pwsh -File ./omanfo/scripts/validation/Test-ManifestConsistency.ps1
   ```

### Scenario: Renaming a script

1. Rename the script file
2. Update any references in SKILL.md or documentation
3. Check if evaluations reference the old name
4. Test locally (all validations)

### Scenario: Removing a feature

1. Delete the script(s)
2. Delete the evaluation file
3. Update `manifest.json` counts
4. Test coverage is still above 80%

---

## Getting Help

If you're still stuck after trying these fixes:

1. **Check the validation script source** - Scripts are well-documented:
   - `omanfo/scripts/validation/README.md`
   - Individual script files have detailed comments

2. **Review recent changes** - Use `git log` and `git diff` to see what changed

3. **Compare with working version** - Check the main branch or a passing CI run

4. **Check GitHub Actions logs** - Full output is available in the workflow run

---

## Exit Codes Reference

All validation scripts use standard exit codes:

| Code | Meaning |
|------|---------|
| `0` | Success - all checks passed |
| `1` | Failure - one or more checks failed |

PowerShell also sets `$LASTEXITCODE` which can be checked:

```powershell
pwsh -File ./script.ps1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Success!"
} else {
    Write-Host "Failed!"
}
```

---

## Preventing CI Failures

**Pre-commit checklist:**

- [ ] Run manifest consistency check
- [ ] Run coverage validation
- [ ] Ensure all new scripts have evaluations
- [ ] Test installation locally
- [ ] Update manifest.json counts if files added/removed
- [ ] Check PowerShell syntax with `Get-Command` or IDE

**Before opening a PR:**

- [ ] All local validations pass
- [ ] Coverage is at 100% (or document why it's lower)
- [ ] Documentation is updated if needed
- [ ] Commit messages are clear

This ensures CI will pass first time! 🎯
