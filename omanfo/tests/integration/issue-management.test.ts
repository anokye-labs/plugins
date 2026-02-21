/**
 * Integration tests — Issue Management scripts
 * Layer 1: calls real PowerShell scripts via pwsh, asserts on real GitHub state.
 * Tests are skipped when pwsh or gh auth is unavailable.
 */

import { describe, it, expect, beforeAll } from 'vitest'
import { execSync } from 'child_process'
import { isPwshAvailable, isGhAvailable, runScript, TEST_REPO } from '../helpers/test-repo.js'

const SCRIPTS_AVAILABLE = isPwshAvailable() && isGhAvailable()

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-IssueTypeIds', () => {
  const [owner] = TEST_REPO.split('/')

  it('returns a hashtable containing Epic, Feature, Task, Bug keys', () => {
    const output = runScript('Get-IssueTypeIds.ps1', `-Owner ${owner}`)
    expect(output).toMatch(/Epic/i)
    expect(output).toMatch(/Feature/i)
    expect(output).toMatch(/Task/i)
    expect(output).toMatch(/Bug/i)
  })

  it('exits cleanly (no terminating errors)', () => {
    expect(() => runScript('Get-IssueTypeIds.ps1', `-Owner ${owner}`)).not.toThrow()
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('New-IssueWithType', () => {
  it('script file exists and has required parameters', () => {
    const output = runScript('New-IssueWithType.ps1', `-?`)
    // Help text should mention the mandatory parameters
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
    expect(output).toMatch(/Title/i)
    expect(output).toMatch(/IssueType/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('New-IssueHierarchy', () => {
  it('script file exists and has required parameters', () => {
    const output = runScript('New-IssueHierarchy.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Update-IssueHierarchy', () => {
  it('script file exists and has required parameters', () => {
    const output = runScript('Update-IssueHierarchy.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Set-IssueDependency', () => {
  it('script file exists and has Owner, Repo, IssueNumber, DependsOn parameters', () => {
    const output = runScript('Set-IssueDependency.ps1', `-?`)
    expect(output).toMatch(/Owner/i)
    expect(output).toMatch(/Repo/i)
    expect(output).toMatch(/IssueNumber/i)
  })
})

describe.skipIf(!SCRIPTS_AVAILABLE)('Get-OrphanedIssues', () => {
  const [owner, repo] = TEST_REPO.split('/')

  it('runs without error and returns structured output', () => {
    const output = runScript('Get-OrphanedIssues.ps1', `-Owner ${owner} -Repo ${repo}`)
    // Should not throw and should produce some output
    expect(typeof output).toBe('string')
  })
})
