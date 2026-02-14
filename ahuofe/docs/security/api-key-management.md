# API Key Management Review

**Issue:** #102
**Date:** 2025-07-17
**Scope:** copilot-media-plugins GitHub Copilot Extension

---

## Overview

This document reviews API key management practices for the copilot-media-plugins project. The project integrates with **fal.ai** (requires `FAL_KEY`) and **ImageSorcery MCP** (local, no authentication required).

## Key Inventory

| Key | Service | Required | Storage | Rotation |
|-----|---------|----------|---------|----------|
| `FAL_KEY` | fal.ai API | Yes | Environment variable | Manual |
| *(none)* | ImageSorcery MCP | No | N/A — runs locally | N/A |

`FAL_KEY` is the **only external API key** needed. ImageSorcery MCP runs as a local process with no network exposure and requires no authentication.

---

## Key Storage

### Required Practice

- Store `FAL_KEY` exclusively as an **environment variable** (`$env:FAL_KEY`).
- **Never** hardcode keys in scripts, SKILL.md files, documentation, or configuration.
- **Never** pass keys as command-line arguments (visible in process lists).

### User Setup Guidance

**Option 1: PowerShell Profile (Recommended for Development)**

Add to `$PROFILE` (e.g., `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`):

```powershell
$env:FAL_KEY = "your-fal-key-here"
```

Restart the terminal after editing.

**Option 2: .env File (For Project-Scoped Use)**

Create a `.env` file in the project root:

```
FAL_KEY=your-fal-key-here
```

> ⚠️ `.env` is already in `.gitignore`. Never commit this file.

**Option 3: System Environment Variable (Persistent)**

```powershell
[System.Environment]::SetEnvironmentVariable('FAL_KEY', 'your-key', 'User')
```

---

## Key Validation

Scripts **must** validate key presence before making API calls and provide clear error messages:

```powershell
if (-not $env:FAL_KEY) {
    Write-Error "FAL_KEY environment variable is not set. Set it via `$env:FAL_KEY = 'your-key'` or in your PowerShell profile."
    return
}
```

### Validation Requirements

- [ ] Check `$env:FAL_KEY` is set and non-empty before any fal.ai API call
- [ ] Provide actionable error message with setup instructions
- [ ] Do not reveal partial key values in error messages
- [ ] Fail fast — do not proceed with empty/invalid keys

---

## Key Rotation

### Procedure

1. **Generate** a new API key in the [fal.ai dashboard](https://fal.ai/dashboard/keys)
2. **Update** the environment variable with the new key:
   ```powershell
   $env:FAL_KEY = "new-key-value"
   ```
3. **Verify** the new key works by running a test API call
4. **Revoke** the old key in the fal.ai dashboard
5. **Update** CI/CD secrets if applicable (see CI/CD section)

### Zero-Downtime Rotation

For CI/CD pipelines:
1. Add the new key as a **second** GitHub Actions secret (e.g., `FAL_KEY_NEW`)
2. Update workflows to use the new secret name
3. Verify pipelines pass with the new key
4. Remove the old secret
5. Rename the new secret back to `FAL_KEY`

---

## CI/CD Security

### GitHub Actions Secrets

- Store `FAL_KEY` as a **repository secret** in GitHub Actions settings
- Reference via `${{ secrets.FAL_KEY }}` in workflows
- **Never** use `echo`, `Write-Output`, or logging that could expose the key

### Pipeline Rules

- [ ] Keys are passed only via `secrets` context, never `env` literals in YAML
- [ ] No `echo $FAL_KEY` or `Write-Output $env:FAL_KEY` in any workflow step
- [ ] Mask secrets in output: GitHub Actions automatically masks `secrets.*` values
- [ ] Use `--quiet` flags where available to minimize output surface

---

## Audit Checklist

Run these checks to verify no keys are leaked in the repository:

### 1. Git History Scan

```powershell
# Search entire git history for potential key leaks
git log --all -p | Select-String 'FAL_KEY|fal-ai|sk-'
```

**Expected result:** No matches containing actual key values. References in documentation (like this file) are acceptable.

### 2. Hardcoded URL Check

```powershell
# Check for API keys embedded in URLs
git grep -i 'key=' -- '*.ps1' '*.md' '*.json' '*.yaml' '*.yml'
```

**Expected result:** No URLs containing API key query parameters.

### 3. .gitignore Coverage

Verify `.gitignore` includes:
- [x] `.env` and `.env.*`
- [x] `*.key`
- [x] `secrets/`
- [x] `*.pem`
- [x] `credentials.json`
- [x] `secrets.json`

### 4. File System Scan

```powershell
# Check for files that might contain secrets
Get-ChildItem -Recurse -Include *.env,*.key,*.pem,secrets.json,credentials.json
```

**Expected result:** No matches in tracked directories.

---

## Risk Matrix

| Scenario | Likelihood | Impact | Risk Level | Mitigation |
|----------|-----------|--------|------------|------------|
| Key committed to git history | Low | **High** — key exposed to all repo viewers | **High** | Pre-commit hooks, `.gitignore`, audit scans |
| Key logged in CI output | Low | **High** — visible in build logs | **High** | GitHub Actions secret masking, no echo/log |
| Key in PowerShell history | Medium | Medium — local exposure only | **Medium** | Use `$env:` from profile, not interactive commands |
| Key in error messages | Low | Medium — could appear in logs | **Medium** | Validate without revealing key content |
| Key in `.env` file shared | Low | Medium — shared with file recipients | **Low** | `.gitignore` coverage, documentation |
| No key set (service failure) | Medium | Low — functionality unavailable | **Low** | Clear validation and error messages |
| ImageSorcery unauthorized access | Very Low | Low — local-only, no secrets | **Low** | No mitigation needed — no auth surface |

---

## References

- [fal.ai API Key Management](https://fal.ai/docs)
- [GitHub Actions Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
