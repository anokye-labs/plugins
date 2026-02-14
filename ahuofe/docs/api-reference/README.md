# API Reference

Reference documentation for PowerShell scripts, fal.ai integration, and ImageSorcery MCP tools.

## Overview

The Copilot Media Plugins extension exposes functionality through:

1. **PowerShell Scripts** — Command-line tools for media generation, processing, and management
2. **ImageSorcery MCP Tools** — Image manipulation operations available via MCP server

## Sections

| Section | Description |
|---------|-------------|
| [Scripts](scripts.md) | PowerShell script reference — parameters, returns, and examples |
| [MCP Tools](mcp-tools.md) | ImageSorcery MCP tool reference — detection, manipulation, annotation |

## Conventions

### Script Naming

All scripts follow PowerShell's `Verb-Noun` pattern with the `Fal` prefix:

- `Invoke-Fal*` — Execute an operation (generate, upscale, edit)
- `New-Fal*` — Create a resource (workflow definition)
- `Get-Fal*` — Retrieve information (schema, pricing, usage)

### Parameter Patterns

Common parameters shared across scripts:

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Model` | string | fal.ai model identifier |
| `-OutputPath` | string | Local path for saving results |
| `-Timeout` | int | Request timeout in seconds (default: 120) |
| `-Verbose` | switch | Enable detailed logging |

### Error Handling

All scripts return structured error objects with:
- Error code and message
- Suggested next action
- Available alternatives (when applicable)
