/**
 * E2E tests — Status Commands via okyerema
 * Layer 2: sends /sitrep and /health commands via the Copilot SDK and validates responses.
 * Tests are skipped when a Copilot token is not available.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { createTestSession, isCopilotAvailable, type TestSession } from '../helpers/copilot-session.js'
import { TEST_REPO } from '../helpers/test-repo.js'

const SDK_AVAILABLE = isCopilotAvailable()
const [OWNER, REPO] = TEST_REPO.split('/')

describe.skipIf(!SDK_AVAILABLE)('Status Commands — /sitrep', () => {
  let session: TestSession

  beforeAll(async () => {
    session = await createTestSession()
  })

  afterAll(async () => {
    await session?.stop()
  })

  it('responds to /sitrep with non-empty output', async () => {
    const response = await session.sendAndWait(`/sitrep --owner ${OWNER} --repo ${REPO}`)
    expect(response.trim().length).toBeGreaterThan(0)
  })

  it('invokes at least one tool for /sitrep', async () => {
    expect(session.toolCalls.length).toBeGreaterThan(0)
  })
})

describe.skipIf(!SDK_AVAILABLE)('Status Commands — /health', () => {
  let session: TestSession

  beforeAll(async () => {
    session = await createTestSession()
  })

  afterAll(async () => {
    await session?.stop()
  })

  it('responds to /health with non-empty output', async () => {
    const response = await session.sendAndWait(`/health --owner ${OWNER} --repo ${REPO}`)
    expect(response.trim().length).toBeGreaterThan(0)
  })

  it('response mentions HealthScore', async () => {
    const response = await session.sendAndWait(`/health --owner ${OWNER} --repo ${REPO}`)
    expect(response).toMatch(/HealthScore/i)
  })

  it('invokes at least one tool for /health', async () => {
    expect(session.toolCalls.length).toBeGreaterThan(0)
  })
})

describe.skipIf(!SDK_AVAILABLE)('Status Commands — /whatsleft', () => {
  let session: TestSession

  beforeAll(async () => {
    session = await createTestSession()
  })

  afterAll(async () => {
    await session?.stop()
  })

  it('responds to /whatsleft with non-empty output', async () => {
    const response = await session.sendAndWait(`/whatsleft --owner ${OWNER} --repo ${REPO}`)
    expect(response.trim().length).toBeGreaterThan(0)
  })
})
