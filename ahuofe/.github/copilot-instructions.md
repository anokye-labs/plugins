# Ahuofe Plugin — Copilot Instructions

Ahuofe is a media generation and manipulation plugin for the Anokye System. It integrates fal.ai cloud APIs for AI media generation and ImageSorcery MCP for local image processing.

## Plugin Structure

- `scripts/` — PowerShell scripts using the shared `FalAi.psm1` module
- `skills/` — Skill definitions: `fal-ai`, `fal-workflow`, `image-sorcery`, `media-agents`
- `tests/` — Pester 5 tests organized by tier: `unit/`, `integration/`, `e2e/`, `evaluation/`, `gates/`
- `docs/` — Documentation: architecture, user guides, API reference, security

## Key Conventions

- All scripts import `scripts/FalAi.psm1` and use `Invoke-FalApi`, `Wait-FalJob`, `Send-FalFile`
- Use `[System.IO.Path]::GetTempPath()` (not `$env:TEMP`) for cross-platform temp paths
- SKILL.md files must stay under 500 lines
- Tests use Pester 5 — run with `Invoke-Pester -Path ./tests/unit`

## Environment

Set `FAL_KEY` environment variable or add `FAL_KEY=<key>` to a `.env` file in the working directory.

## Running Tests

```powershell
# Unit tests (no API key needed)
Invoke-Pester -Path ./tests/unit -Output Detailed

# Gate tests (structure validation)
Invoke-Pester -Path ./tests/gates -Output Detailed

# All tests
Invoke-Pester -Path ./tests -Output Detailed
```
