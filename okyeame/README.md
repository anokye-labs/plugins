# Okyeame — The Linguist

The Okyeame (linguist) is the voice of the Anokye
System. It gives status updates, reports on blocked issues, asks for
clarity when needed, and invokes the Okyerema when the asafo need their rhythm set.

## What It Does

- **Creates and manages issues** with proper types (Epic, Feature, Task, Bug)
- **Builds hierarchies** using the sub-issues API
- **Reports status** via slash commands (/sitrep, /prcheck, /health, etc.)
- **Coordinates agents** by creating fully-specified issues for @copilot
- **Invokes Okyerema** for workflow automation configuration

## What It Does NOT Do

- ❌ Write, edit, or review code
- ❌ Create branches or pull requests
- ❌ Configure workflows (delegates to Okyerema)

## Installation

Copy the `.github/skills/okyeame/` directory into your repository's
`.github/skills/` directory. The Okyeame agent requires the Okyerema skill
to be available for workflow automation capabilities.

## Related

- **[Okyerema](../okyerema/)** — Workflow automation skill (the master drummer)
- **[The Anokye System](../okyerema/.github/skills/okyerema/references/agentic-workflows.md)** — Full architecture reference
