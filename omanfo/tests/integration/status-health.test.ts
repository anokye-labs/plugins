/**
 * Integration tests — Status & Health scripts
 * Layer 1: calls real PowerShell scripts via pwsh, asserts on real GitHub state.
 * Tests are skipped when pwsh or gh auth is unavailable.
 */

import { describe, it, expect } from 'vitest'
import { isPwshAvailable, isGhAvailable, runScript, TEST_REPO } from '../helpers/test-repo.js'

const SCRIPTS_AVAILABLE = isPwshAvailable() && isGhAvailable()

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-Sitrep', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('runs without error', () => {
    expect(() => runScript('Get-Sitrep.ps1', `-Owner ${owner} -Repo ${repo}`)).not.toThrow()
  })

  it('returns non-empty output', () => {
    const output = runScript('Get-Sitrep.ps1', `-Owner ${owner} -Repo ${repo}`)
    expect(output.trim().length).toBeGreaterThan(0)
  })

  it('Brief flag produces shorter output than full report', () => {
    const full = runScript('Get-Sitrep.ps1', `-Owner ${owner} -Repo ${repo}`)
    const brief = runScript('Get-Sitrep.ps1', `-Owner ${owner} -Repo ${repo} -Brief`)
    expect(brief.length).toBeLessThan(full.length)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Invoke-DagHealthCheck', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('runs without error', () => {
    expect(() =>
      runScript('Invoke-DagHealthCheck.ps1', `-Owner ${owner} -Repo ${repo}`)
    ).not.toThrow()
  })

  it('output includes HealthScore field', () => {
    const output = runScript('Invoke-DagHealthCheck.ps1', `-Owner ${owner} -Repo ${repo}`)
    expect(output).toMatch(/HealthScore/i)
  })

  it('output includes TypeCounts field', () => {
    const output = runScript('Invoke-DagHealthCheck.ps1', `-Owner ${owner} -Repo ${repo}`)
    expect(output).toMatch(/TypeCounts/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-HierarchyHealth', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('runs without error', () => {
    expect(() =>
      runScript('Get-HierarchyHealth.ps1', `-Owner ${owner} -Repo ${repo}`)
    ).not.toThrow()
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-DagStatus', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('runs without error', () => {
    expect(() =>
      runScript('Get-DagStatus.ps1', `-Owner ${owner} -Repo ${repo}`)
    ).not.toThrow()
  })

  it('Brief flag produces output', () => {
    const output = runScript('Get-DagStatus.ps1', `-Owner ${owner} -Repo ${repo} -Brief`)
    expect(typeof output).toBe('string')
  })
})
