/**
 * E2E tests — Skill Loading
 * Layer 2: verifies the okyerema skill loads successfully via the Copilot SDK.
 * Tests are skipped when a Copilot token is not available.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { createTestSession, isCopilotAvailable, type TestSession } from '../helpers/copilot-session.js'

const SDK_AVAILABLE = isCopilotAvailable()

describe.skipIf(!SDK_AVAILABLE)('Skill Loading', () => {
  let session: TestSession

  beforeAll(async () => {
    session = await createTestSession()
  })

  afterAll(async () => {
    await session?.stop()
  })

  it('starts the Copilot SDK client without error', () => {
    expect(session.client).toBeDefined()
  })

  it('creates a session with the okyerema skill loaded', () => {
    expect(session.session).toBeDefined()
  })

  it('responds to a simple prompt', async () => {
    const response = await session.sendAndWait('What skills do you have available?')
    expect(response.trim().length).toBeGreaterThan(0)
  })

  it('acknowledges okyerema in its response', async () => {
    const response = await session.sendAndWait(
      'List the skill names you have loaded. Reply with just the names, one per line.'
    )
    expect(response.toLowerCase()).toMatch(/okyerema/i)
  })
})
