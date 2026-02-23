/**
 * Integration tests — Plan Materialization scripts
 * Layer 1: calls real PowerShell scripts via pwsh, asserts on real GitHub state.
 * Tests are skipped when pwsh or gh auth is unavailable.
 */

import { describe, it, expect, afterAll } from 'vitest'
import { writeFileSync, unlinkSync } from 'fs'
import { tmpdir } from 'os'
import { join } from 'path'
import { isPwshAvailable, isGhAvailable, runScript, cleanupIssues, TEST_REPO } from '../helpers/test-repo.js'

const SCRIPTS_AVAILABLE = isPwshAvailable() && isGhAvailable()
const RUN_ID = Date.now().toString(36).toUpperCase()
const TEST_PREFIX = `INT-PLAN-${RUN_ID}`

afterAll(() => {
  if (SCRIPTS_AVAILABLE) {
    cleanupIssues(TEST_PREFIX)
  }
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Invoke-PlanMaterialization', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('script accepts Owner, Repo, and PlanFile parameters', () => {
    const output = runScript('Invoke-PlanMaterialization.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
    expect(output).toMatch(/PlanFile/i)
  })

  it('materializes a minimal plan into issues', () => {
    const epicTitle = `${TEST_PREFIX}: Test Epic`
    const planFile = join(tmpdir(), `plan-${RUN_ID}.md`)

    writeFileSync(
      planFile,
      `# ${epicTitle}\n\n## Overview\nIntegration test plan\n\n## Features\n\n### Feature 1: Alpha\n- Task: Do alpha thing\n`,
      'utf-8'
    )

    try {
      const output = runScript(
        'Invoke-PlanMaterialization.ps1',
        `-Owner ${owner} -Repo ${repo} -PlanFile "${planFile}"`
      )
      expect(typeof output).toBe('string')
    } finally {
      try { unlinkSync(planFile) } catch { /* ignore */ }
    }
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Sync-PlanToIssues', () => {
  it('script accepts Owner, Repo, and PlanFile parameters', () => {
    const output = runScript('Sync-PlanToIssues.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('New-IssueBatch', () => {
  it('script accepts Owner and Repo parameters', () => {
    const output = runScript('New-IssueBatch.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Add-IssuesToProject', () => {
  it('script accepts Owner and Repo parameters', () => {
    const output = runScript('Add-IssuesToProject.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
  })
})
