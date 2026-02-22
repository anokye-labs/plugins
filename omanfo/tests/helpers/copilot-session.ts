/**
 * copilot-session.ts
 * SDK session factory with okyerema skill loading for E2E tests.
 */

import { CopilotClient } from '@github/copilot-sdk'
import { resolve } from 'path'
import { fileURLToPath } from 'url'
import { dirname } from 'path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

export interface TestSessionOptions {
  /** Override skill directories (default: omanfo skills directory) */
  skillDirs?: string[]
  /** Model to use (default: gpt-4.1) */
  model?: string
}

export interface TestSession {
  client: CopilotClient
  session: ReturnType<CopilotClient['createSession']> extends Promise<infer T> ? T : never
  toolCalls: string[]
  /** Send a prompt and return the response text */
  sendAndWait: (prompt: string) => Promise<string>
  /** Stop the client and destroy the session */
  stop: () => Promise<void>
}

/**
 * Create a Copilot SDK test session with the okyerema skill loaded.
 * Returns helpers for sending prompts and capturing tool calls.
 */
export async function createTestSession(opts?: TestSessionOptions): Promise<TestSession> {
  const client = new CopilotClient()
  await client.start()

  const toolCalls: string[] = []

  const pluginRoot = resolve(__dirname, '../../../')
  const skillDirectories = opts?.skillDirs ?? [resolve(pluginRoot, 'skills')]

  const session = await client.createSession({
    model: opts?.model ?? 'gpt-4.1',
    skillDirectories,
    hooks: {
      onPreToolUse: async (input: { toolName: string }) => {
        toolCalls.push(input.toolName)
        return { permissionDecision: 'allow' as const }
      },
    },
  })

  async function sendAndWait(prompt: string): Promise<string> {
    const result = await session.sendAndWait({ prompt })
    return result?.data?.content ?? ''
  }

  async function stop(): Promise<void> {
    try {
      await session.destroy()
    } catch {
      // ignore destroy errors
    }
    try {
      await client.stop()
    } catch {
      // ignore stop errors
    }
  }

  return { client, session, toolCalls, sendAndWait, stop }
}

/**
 * Return true when the Copilot SDK token is configured in the environment.
 * Uses a dedicated COPILOT_TOKEN env var to avoid false positives from
 * GITHUB_TOKEN which may be set for other purposes (CI, gh CLI, etc.).
 */
export function isCopilotAvailable(): boolean {
  return Boolean(process.env.COPILOT_TOKEN)
}
