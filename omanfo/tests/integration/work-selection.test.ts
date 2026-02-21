/**
 * Integration tests — Work Selection scripts
 * Layer 1: calls real PowerShell scripts via pwsh, asserts on real GitHub state.
 * Tests are skipped when pwsh or gh auth is unavailable.
 */

import { describe, it, expect } from 'vitest'
import { isPwshAvailable, isGhAvailable, runScript, TEST_REPO } from '../helpers/test-repo.js'

const SCRIPTS_AVAILABLE = isPwshAvailable() && isGhAvailable()

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-ReadyIssues', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('runs without error', () => {
    expect(() =>
      runScript('Get-ReadyIssues.ps1', `-Owner ${owner} -Repo ${repo}`)
    ).not.toThrow()
  })

  it('output contains ReadyIssues field', () => {
    const output = runScript('Get-ReadyIssues.ps1', `-Owner ${owner} -Repo ${repo}`)
    expect(output).toMatch(/ReadyIssues/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-BlockedIssues', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('runs without error', () => {
    expect(() =>
      runScript('Get-BlockedIssues.ps1', `-Owner ${owner} -Repo ${repo}`)
    ).not.toThrow()
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-StalledWork', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('runs without error', () => {
    expect(() =>
      runScript('Get-StalledWork.ps1', `-Owner ${owner} -Repo ${repo}`)
    ).not.toThrow()
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Test-Hierarchy', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('runs without error', () => {
    expect(() =>
      runScript('Test-Hierarchy.ps1', `-Owner ${owner} -Repo ${repo}`)
    ).not.toThrow()
  })
})
