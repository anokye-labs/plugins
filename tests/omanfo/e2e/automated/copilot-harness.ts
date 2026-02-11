/**
 * Shared test harness for Copilot SDK E2E tests
 * Handles client lifecycle and skill loading
 */

import { CopilotClient } from '@github/copilot-sdk';
import { resolve } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export interface TestConfig {
  model?: string;
  skillDirectories?: string[];
  tools?: any[];
}

export interface TestResult {
  content: string;
  toolCalls: string[];
  success: boolean;
  error?: string;
}

export class CopilotTestHarness {
  private client: CopilotClient | null = null;
  private session: any = null;
  private toolCallLog: string[] = [];

  /**
   * Initialize the Copilot client and create a session
   */
  async start(config: TestConfig = {}): Promise<void> {
    try {
      this.client = new CopilotClient();
      await this.client.start();

      // Resolve skill directory paths relative to plugin root
      const pluginRoot = resolve(__dirname, '../../../../omanfo');
      const skillDirectories = config.skillDirectories || [
        resolve(pluginRoot, 'skills')
      ];

      this.session = await this.client.createSession({
        model: config.model || 'gpt-4o',
        skillDirectories,
        tools: config.tools || [],
        hooks: {
          onPreToolUse: (input: any, invocation: any) => {
            console.log(`[PreTool] ${input.toolName}`);
            this.toolCallLog.push(input.toolName);
            return { permissionDecision: "allow" };
          },
          onPostToolUse: (input: any, invocation: any) => {
            console.log(`[PostTool] ${input.toolName} -> completed`);
          }
        }
      });

      console.log('✓ Copilot SDK client started');
      console.log(`✓ Skills loaded from: ${skillDirectories.join(', ')}`);
    } catch (error) {
      console.error('Failed to start Copilot SDK:', error);
      throw error;
    }
  }

  /**
   * Send a prompt and wait for response
   */
  async sendAndWait(prompt: string): Promise<TestResult> {
    if (!this.session) {
      throw new Error('Session not initialized. Call start() first.');
    }

    try {
      console.log(`\n📤 Sending prompt: "${prompt}"`);
      this.toolCallLog = []; // Reset tool log for this prompt

      const result = await this.session.sendAndWait({ prompt });

      // SDK returns AssistantMessageEvent with data.content
      const content = result?.data?.content || result?.content || '';
      
      console.log(`📥 Response received`);
      console.log(`   Content length: ${content.length} chars`);
      console.log(`   Tools called: ${this.toolCallLog.join(', ') || 'none'}`);

      return {
        content,
        toolCalls: [...this.toolCallLog],
        success: true
      };
    } catch (error) {
      console.error('Error sending prompt:', error);
      return {
        content: '',
        toolCalls: [...this.toolCallLog],
        success: false,
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  /**
   * Stop the client and cleanup
   */
  async stop(): Promise<void> {
    try {
      // Destroy session before stopping client
      if (this.session) {
        await this.session.destroy();
        console.log('✓ Session destroyed');
      }
    } catch (error) {
      console.error('Error destroying session:', error);
    }
    
    if (this.client) {
      try {
        await this.client.stop();
        console.log('✓ Copilot SDK client stopped');
      } catch (error) {
        console.error('Error stopping client:', error);
      } finally {
        this.client = null;
        this.session = null;
        this.toolCallLog = [];
      }
    }
  }

  /**
   * Get the list of tools that were called
   */
  getToolCalls(): string[] {
    return [...this.toolCallLog];
  }
}

/**
 * Helper function to run a simple test scenario
 */
export async function runTest(
  testName: string,
  prompt: string,
  validations: {
    shouldContain?: string[];
    shouldCallTools?: string[];
    shouldNotBeEmpty?: boolean;
  } = {}
): Promise<boolean> {
  const harness = new CopilotTestHarness();
  let success = true;

  try {
    console.log(`\n${'='.repeat(60)}`);
    console.log(`🧪 Test: ${testName}`);
    console.log('='.repeat(60));

    await harness.start();
    const result = await harness.sendAndWait(prompt);

    if (!result.success) {
      console.error(`❌ Test failed: ${result.error}`);
      return false;
    }

    // Validate response is not empty
    if (validations.shouldNotBeEmpty !== false && !result.content) {
      console.error('❌ Validation failed: Response content is empty');
      success = false;
    }

    // Validate content contains expected strings
    if (validations.shouldContain) {
      for (const expected of validations.shouldContain) {
        if (!result.content.includes(expected)) {
          console.error(`❌ Validation failed: Content does not contain "${expected}"`);
          success = false;
        } else {
          console.log(`✓ Content contains "${expected}"`);
        }
      }
    }

    // Validate expected tools were called
    if (validations.shouldCallTools) {
      for (const toolName of validations.shouldCallTools) {
        if (!result.toolCalls.includes(toolName)) {
          console.error(`❌ Validation failed: Tool "${toolName}" was not called`);
          console.error(`   Tools called: ${result.toolCalls.join(', ') || 'none'}`);
          success = false;
        } else {
          console.log(`✓ Tool "${toolName}" was called`);
        }
      }
    }

    if (success) {
      console.log(`\n✅ Test "${testName}" PASSED`);
    } else {
      console.log(`\n❌ Test "${testName}" FAILED`);
    }

    return success;
  } catch (error) {
    console.error(`❌ Test "${testName}" threw exception:`, error);
    return false;
  } finally {
    await harness.stop();
  }
}
