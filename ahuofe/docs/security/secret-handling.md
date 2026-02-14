# Secret Handling Review

**Issue:** #103
**Date:** 2025-07-17
**Scope:** copilot-media-plugins GitHub Copilot Extension

---

## Overview

This document reviews how secrets and sensitive data are handled across the copilot-media-plugins project. It covers API keys, generated content, user input, transport security, and operational practices.

## Secret Types

| Secret Type | Sensitivity | Storage | Lifetime |
|-------------|------------|---------|----------|
| `FAL_KEY` (API key) | **High** | Environment variable only | Until rotated |
| Generated image URLs | Medium | Temporary — returned by fal.ai | Session-scoped |
| User prompts | Medium | In-memory only | Request-scoped |
| Generated output files | Low–Medium | Temp directory | Cleaned after use |

---

## Transport Security

### fal.ai API

- **All** fal.ai API calls **must** use HTTPS (`https://fal.ai/...`)
- PowerShell `Invoke-RestMethod` and `Invoke-WebRequest` enforce TLS by default
- Set minimum TLS version explicitly in scripts:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### ImageSorcery MCP

- Runs **locally only** — no network transport
- Communicates via stdio (standard input/output) with the MCP host
- No TLS configuration needed

---

## Logging Requirements

### Never Log

- API key values (`$env:FAL_KEY`)
- Full Authorization headers
- Raw API responses containing signed URLs

### Safe to Log

- API endpoint names (without query parameters)
- HTTP status codes
- Error messages (after redaction)
- File paths of generated outputs

### Redaction in Verbose Output

When scripts use `-Verbose` or debug output, redact sensitive parameters:

```powershell
# BAD - exposes key
Write-Verbose "Calling fal.ai with key: $env:FAL_KEY"

# GOOD - redacted
Write-Verbose "Calling fal.ai with key: ***"

# GOOD - no key reference
Write-Verbose "Calling fal.ai endpoint: $endpoint"
```

### Log Audit

```powershell
# Scan scripts for potential logging of secrets
Select-String -Path *.ps1 -Pattern 'Write-(Output|Verbose|Debug|Host).*FAL_KEY'
```

**Expected result:** No matches.

---

## File System Security

### Generated Output

- Generated images and media **must** be written to temporary directories
- Use `[System.IO.Path]::GetTempPath()` or a project-local `output/` directory
- Clean up generated files after use or at session end

```powershell
# Create temp directory for outputs
$outputDir = Join-Path ([System.IO.Path]::GetTempPath()) "copilot-media-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

# Clean up after use
Remove-Item -Path $outputDir -Recurse -Force
```

### Path Traversal Prevention

Validate output paths to prevent directory traversal:

```powershell
function Test-SafePath {
    param([string]$BasePath, [string]$RequestedPath)
    $resolved = [System.IO.Path]::GetFullPath($RequestedPath)
    return $resolved.StartsWith([System.IO.Path]::GetFullPath($BasePath))
}
```

---

## .gitignore Requirements

The following patterns **must** be present in `.gitignore`:

| Pattern | Purpose | Status |
|---------|---------|--------|
| `.env` | Environment variable files | ✅ Present |
| `.env.local` | Local environment overrides | ✅ Present |
| `.env.*.local` | Scoped environment files | ✅ Present |
| `*.env` | Any env file variant | ✅ Present |
| `*.key` | Key files | ✅ Present |
| `*.pem` | Certificate/key files | ✅ Present |
| `secrets/` | Secrets directory | ✅ Present |
| `secrets.json` | Secrets JSON | ✅ Present |
| `credentials.json` | Credentials file | ✅ Present |
| `output/` | Generated output files | ✅ Present |
| `temp/` | Temporary files | ✅ Present |

---

## PowerShell Best Practices

### Use Environment Variables for Secrets

```powershell
# GOOD - from environment
$key = $env:FAL_KEY

# BAD - from command-line args (visible in process list)
param([string]$ApiKey)
```

### SecureString for Interactive Key Input

When accepting keys interactively (not the normal flow):

```powershell
$secureKey = Read-Host -Prompt "Enter FAL_KEY" -AsSecureString
$env:FAL_KEY = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
)
```

### Clear Sensitive Variables

After use, clear variables that held sensitive data:

```powershell
# Clear after API call completes
Remove-Variable -Name key -ErrorAction SilentlyContinue
[System.GC]::Collect()
```

### Avoid Transcription Leaks

If PowerShell transcription is enabled, secrets in variables may be captured:

```powershell
# Check if transcription is active
if ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -ErrorAction SilentlyContinue).EnableTranscripting) {
    Write-Warning "PowerShell transcription is enabled. Secrets may be logged."
}
```

---

## MCP Security — ImageSorcery

| Property | Status |
|----------|--------|
| Network access | **None** — local stdio only |
| Authentication | **None required** |
| Input validation | MCP protocol handles message framing |
| File system access | Limited to specified paths |
| Privilege level | Same as host process |

### MCP-Specific Considerations

- ImageSorcery runs in the same security context as the Copilot host process
- It reads/writes files only as directed by the MCP host
- No outbound network connections — no data exfiltration risk via MCP
- File operations should be validated for path traversal (see File System Security above)

---

## Threat Model

### 1. Key Exfiltration via Git Commits

| | Details |
|---|---|
| **Threat** | `FAL_KEY` accidentally committed to repository |
| **Likelihood** | Low (`.gitignore` and documentation mitigate) |
| **Impact** | High — key exposed to all repository viewers |
| **Mitigation** | `.gitignore` patterns, pre-commit scanning, audit checklist |
| **Detection** | `git log --all -p \| Select-String 'FAL_KEY\|sk-'` |
| **Response** | Rotate key immediately, use `git filter-branch` or BFG to purge |

### 2. Key Exposure via Logs/Output

| | Details |
|---|---|
| **Threat** | API key printed to console, CI logs, or transcription files |
| **Likelihood** | Low–Medium (depends on script discipline) |
| **Impact** | High — key visible in logs, potentially archived |
| **Mitigation** | Never log key values, redact in verbose output, GitHub Actions masking |
| **Detection** | Scan scripts for `Write-*` referencing `FAL_KEY` |
| **Response** | Rotate key, purge logs containing exposure |

### 3. Prompt Injection via User Input

| | Details |
|---|---|
| **Threat** | Malicious user prompt crafted to manipulate API calls or extract secrets |
| **Likelihood** | Low (Copilot mediates input) |
| **Impact** | Medium — could cause unexpected API usage or output |
| **Mitigation** | Copilot Extension framework sanitizes input; fal.ai API validates parameters |
| **Detection** | Monitor for unusual API call patterns or errors |
| **Response** | Review and restrict prompt handling logic |

### 4. Output Path Traversal

| | Details |
|---|---|
| **Threat** | Generated file written to arbitrary file system location |
| **Likelihood** | Low (output paths are typically controlled) |
| **Impact** | Medium — could overwrite system files |
| **Mitigation** | Validate output paths with `Test-SafePath`, use temp directories |
| **Detection** | Audit file write operations in scripts |
| **Response** | Add path validation, restrict output to designated directories |

### 5. Sensitive Content in Generated Images

| | Details |
|---|---|
| **Threat** | Generated images contain sensitive/private content persisted on disk |
| **Likelihood** | Medium (depends on user prompts) |
| **Impact** | Low–Medium — content persisted beyond session |
| **Mitigation** | Write to temp directories, clean up after session |
| **Detection** | Check for orphaned output files |
| **Response** | Implement automated cleanup |

---

## References

- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [PowerShell Security Best Practices](https://learn.microsoft.com/en-us/powershell/scripting/security/)
- [MCP Security Model](https://modelcontextprotocol.io/docs/concepts/security)
- See also: [API Key Management Review](./api-key-management.md)
