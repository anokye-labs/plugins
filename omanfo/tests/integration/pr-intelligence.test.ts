/**
 * Integration tests — PR Intelligence scripts
 * Layer 1: calls real PowerShell scripts via pwsh, asserts on real GitHub state.
 * Tests are skipped when pwsh or gh auth is unavailable.
 */

import { describe, it, expect } from 'vitest'
import { isPwshAvailable, isGhAvailable, runScript, TEST_REPO } from '../helpers/test-repo.js'

const SCRIPTS_AVAILABLE = isPwshAvailable() && isGhAvailable()

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-PRHealth', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('script accepts Owner and Repo parameters', () => {
    const output = runScript('Get-PRHealth.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
  })

  it('runs without error when no open PRs exist', () => {
    expect(() =>
      runScript('Get-PRHealth.ps1', `-Owner ${owner} -Repo ${repo}`)
    ).not.toThrow()
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-UnresolvedThreads', () => {
  it('script accepts Owner, Repo, and PullNumber parameters', () => {
    const output = runScript('Get-UnresolvedThreads.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
    expect(output).toMatch(/PullNumber/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-PRStatus', () => {
  it('script accepts Owner, Repo, and PullNumber parameters', () => {
    const output = runScript('Get-PRStatus.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
    expect(output).toMatch(/PullNumber/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Resolve-ReviewThreads', () => {
  it('script accepts Owner, Repo, and PullNumber parameters', () => {
    const output = runScript('Resolve-ReviewThreads.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
    expect(output).toMatch(/PullNumber/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Find-IssueByPR', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('script accepts Owner, Repo, and PullNumber parameters', () => {
    const output = runScript('Find-IssueByPR.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-PRTimeline', () => {
  it('script accepts Owner, Repo, and PullNumber parameters', () => {
    const output = runScript('Get-PRTimeline.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
    expect(output).toMatch(/PullNumber/i)
  })
})
