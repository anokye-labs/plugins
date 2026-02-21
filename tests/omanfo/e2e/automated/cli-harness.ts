/**
 * Provider-agnostic CLI test harness for E2E tests.
 * Supports both GitHub Copilot CLI and Claude Code CLI.
 *
 * For Copilot SDK-based tests, use copilot-harness.ts instead.
 * This harness works by spawning CLI processes directly.
 */

import { spawn, execFileSync, ChildProcess } from 'child_process';

export type Provider = 'copilot' | 'claude';

export interface CLITestConfig {
  provider: Provider;
  workingDirectory?: string;
  timeoutMs?: number;
  additionalArgs?: string[];
}

export interface CLIResult {
  success: boolean;
  provider: Provider;
  output: string;
  errorOutput: string;
  exitCode: number;
  timedOut: boolean;
  durationMs: number;
}

export interface CLIPatternResult {
  matched: boolean;
  output: string;
  match: RegExpMatchArray | null;
  error: string | null;
}

export interface CLISession {
  provider: Provider;
  process: ChildProcess;
  outputBuffer: string[];
  errorBuffer: string[];
  startTime: number;
  turnCount: number;
}

interface ProviderSpec {
  command: string;
  oneShotArgs: (prompt: string) => string[];
  interactiveArgs: string[];
  installUrl: string;
}

const PROVIDERS: Record<Provider, ProviderSpec> = {
  copilot: {
    command: 'copilot',
    oneShotArgs: (prompt: string) => ['-p', prompt, '--allow-all-tools', '-s'],
    interactiveArgs: [],
    installUrl: 'https://github.com/github/copilot-cli',
  },
  claude: {
    command: 'claude',
    oneShotArgs: (prompt: string) => ['-p', prompt, '--output-format', 'text'],
    interactiveArgs: [],
    installUrl: 'https://docs.anthropic.com/en/docs/claude-code',
  },
};

export function getSupportedProviders(): Provider[] {
  return Object.keys(PROVIDERS) as Provider[];
}

export function isProviderAvailable(provider: Provider): boolean {
  try {
    const cmd = process.platform === 'win32' ? 'where' : 'which';
    execFileSync(cmd, [PROVIDERS[provider].command], { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

export function getAvailableProviders(): Provider[] {
  return getSupportedProviders().filter(isProviderAvailable);
}

export function sendPrompt(
  provider: Provider,
  prompt: string,
  config: Partial<CLITestConfig> = {}
): Promise<CLIResult> {
  const spec = PROVIDERS[provider];
  const timeoutMs = config.timeoutMs ?? 120_000;
  const args = [...spec.oneShotArgs(prompt), ...(config.additionalArgs ?? [])];

  return new Promise((resolve) => {
    const startTime = Date.now();
    let stdout = '';
    let stderr = '';
    let settled = false;
    let exited = false;

    const child = spawn(spec.command, args, {
      cwd: config.workingDirectory,
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env },
    });

    child.stdout!.on('data', (data: Buffer) => {
      stdout += data.toString();
    });

    child.stderr!.on('data', (data: Buffer) => {
      stderr += data.toString();
    });

    const timer = setTimeout(() => {
      if (!settled) {
        settled = true;
        child.kill('SIGTERM');
        setTimeout(() => {
          if (!exited) child.kill('SIGKILL');
        }, 2000);
        resolve({
          success: false,
          provider,
          output: stdout,
          errorOutput: stderr,
          exitCode: -1,
          timedOut: true,
          durationMs: Date.now() - startTime,
        });
      }
    }, timeoutMs);

    child.on('close', (code) => {
      exited = true;
      if (!settled) {
        settled = true;
        clearTimeout(timer);
        resolve({
          success: code === 0,
          provider,
          output: stdout,
          errorOutput: stderr,
          exitCode: code ?? -1,
          timedOut: false,
          durationMs: Date.now() - startTime,
        });
      }
    });

    child.on('error', (err) => {
      if (!settled) {
        settled = true;
        clearTimeout(timer);
        resolve({
          success: false,
          provider,
          output: stdout,
          errorOutput: `Process error: ${err.message}`,
          exitCode: -1,
          timedOut: false,
          durationMs: Date.now() - startTime,
        });
      }
    });
  });
}

// ── Interactive session API ────────────────────────────────────────────────

/**
 * Launches a CLI provider in interactive (REPL) mode.
 * Returns a session object used by sendToSession / waitForPattern / stopSession.
 */
export function startSession(
  provider: Provider,
  options: { workingDirectory?: string; additionalArgs?: string[] } = {}
): CLISession {
  const spec = PROVIDERS[provider];
  const args = [...spec.interactiveArgs, ...(options.additionalArgs ?? [])];

  const child = spawn(spec.command, args, {
    cwd: options.workingDirectory,
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env },
  });

  const session: CLISession = {
    provider,
    process: child,
    outputBuffer: [],
    errorBuffer: [],
    startTime: Date.now(),
    turnCount: 0,
  };

  // Use line buffers to handle partial chunks correctly
  let stdoutPartial = '';
  let stderrPartial = '';

  child.stdout!.on('data', (data: Buffer) => {
    stdoutPartial += data.toString();
    const lines = stdoutPartial.split('\n');
    stdoutPartial = lines.pop() ?? '';
    session.outputBuffer.push(...lines);
  });

  child.stderr!.on('data', (data: Buffer) => {
    stderrPartial += data.toString();
    const lines = stderrPartial.split('\n');
    stderrPartial = lines.pop() ?? '';
    session.errorBuffer.push(...lines);
  });

  // Flush any remaining partial line when the process closes
  child.on('close', () => {
    if (stdoutPartial) {
      session.outputBuffer.push(stdoutPartial);
      stdoutPartial = '';
    }
    if (stderrPartial) {
      session.errorBuffer.push(stderrPartial);
      stderrPartial = '';
    }
  });

  return session;
}

/**
 * Writes a prompt line to the stdin of an interactive CLI session.
 */
export function sendToSession(session: CLISession, prompt: string): void {
  if (!session.process.stdin) {
    throw new Error('Session process has no stdin');
  }
  session.process.stdin.write(prompt + '\n');
  session.turnCount++;
}

/**
 * Drains and returns all accumulated output from the session buffer (non-blocking).
 */
export function getSessionOutput(session: CLISession, includeErrors = false): string {
  const lines = session.outputBuffer.splice(0);
  if (includeErrors) {
    lines.push(...session.errorBuffer.splice(0));
  }
  return lines.join('\n');
}

/**
 * Blocks until a line matching the given regex pattern appears in session output,
 * or until the timeout elapses.
 */
export function waitForPattern(
  session: CLISession,
  pattern: RegExp | string,
  timeoutMs = 30_000,
  includeErrors = false
): Promise<CLIPatternResult> {
  const re = typeof pattern === 'string' ? new RegExp(pattern) : pattern;
  const collectedLines: string[] = [];

  return new Promise((resolve) => {
    const deadline = Date.now() + timeoutMs;

    function poll() {
      // Drain stdout buffer
      const stdoutLines = session.outputBuffer.splice(0);
      collectedLines.push(...stdoutLines);

      if (includeErrors) {
        const stderrLines = session.errorBuffer.splice(0);
        collectedLines.push(...stderrLines);
      }

      // Check all collected lines for the pattern
      for (const line of collectedLines) {
        const m = line.match(re);
        if (m) {
          resolve({
            matched: true,
            output: collectedLines.join('\n'),
            match: m,
            error: null,
          });
          return;
        }
      }

      if (Date.now() >= deadline) {
        resolve({
          matched: false,
          output: collectedLines.join('\n'),
          match: null,
          error: `Timed out after ${timeoutMs}ms waiting for pattern: ${re}`,
        });
        return;
      }

      setTimeout(poll, 100);
    }

    poll();
  });
}

/**
 * Gracefully shuts down an interactive CLI session.
 * Sends '/exit', waits briefly, then kills if needed.
 */
export function stopSession(session: CLISession, gracefulMs = 5000): Promise<void> {
  return new Promise((resolve) => {
    if (session.process.exitCode !== null) {
      resolve();
      return;
    }

    const timer = setTimeout(() => {
      session.process.kill('SIGKILL');
    }, gracefulMs);

    session.process.on('close', () => {
      clearTimeout(timer);
      resolve();
    });

    try {
      if (session.process.stdin) {
        session.process.stdin.write('/exit\n');
        session.process.stdin.end();
      } else {
        session.process.kill('SIGTERM');
      }
    } catch {
      session.process.kill('SIGTERM');
    }
  });
}

// ── GitHub state verification ──────────────────────────────────────────────

export function extractIssueNumbers(text: string): number[] {
  const matches = text.matchAll(/#(\d+)/g);
  return Array.from(matches, (m) => parseInt(m[1], 10));
}

export async function verifyIssue(
  owner: string,
  repo: string,
  issueNumber: number,
  expectations: { title?: string; state?: string } = {}
): Promise<{ passed: boolean; message: string }> {
  try {
    const query = `query {
  repository(owner: "${owner}", name: "${repo}") {
    issue(number: ${issueNumber}) {
      title
      state
      issueType { name }
    }
  }
}`;

    const raw = execFileSync(
      'gh',
      ['api', 'graphql', '-H', 'GraphQL-Features: sub_issues', '-f', `query=${query}`],
      { encoding: 'utf-8' }
    ).toString();
    const result = JSON.parse(raw);
    const issue = result.data?.repository?.issue;

    if (!issue) {
      return { passed: false, message: `Issue #${issueNumber} not found` };
    }

    const failures: string[] = [];

    if (expectations.title && !issue.title.includes(expectations.title)) {
      failures.push(
        `Title mismatch: expected to contain "${expectations.title}", got "${issue.title}"`
      );
    }

    if (expectations.state && issue.state !== expectations.state) {
      failures.push(
        `State mismatch: expected "${expectations.state}", got "${issue.state}"`
      );
    }

    return {
      passed: failures.length === 0,
      message: failures.length > 0 ? failures.join('; ') : 'OK',
    };
  } catch (error) {
    return {
      passed: false,
      message: `API error: ${error instanceof Error ? error.message : String(error)}`,
    };
  }
}

export async function closeTestIssues(
  owner: string,
  repo: string,
  issueNumbers: number[]
): Promise<number> {
  let closed = 0;
  for (const num of issueNumbers) {
    try {
      execFileSync(
        'gh',
        ['api', `repos/${owner}/${repo}/issues/${num}`, '-X', 'PATCH', '-f', 'state=closed', '-f', 'state_reason=not_planned'],
        { stdio: 'pipe' }
      );
      closed++;
    } catch {
      console.warn(`Failed to close issue #${num}`);
    }
  }
  return closed;
}

export interface TestScenario {
  name: string;
  prompt: string;
  validations?: {
    shouldContain?: string[];
    shouldNotBeEmpty?: boolean;
    shouldMatchPattern?: RegExp;
  };
}

export async function runTestScenario(
  provider: Provider,
  scenario: TestScenario,
  config: Partial<CLITestConfig> = {}
): Promise<{ passed: boolean; details: string }> {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`[${provider}] ${scenario.name}`);
  console.log('='.repeat(60));

  const result = await sendPrompt(provider, scenario.prompt, { ...config, provider });

  if (!result.success) {
    const reason = result.timedOut
      ? `Timed out after ${result.durationMs}ms`
      : `Exit code ${result.exitCode}: ${result.errorOutput.slice(0, 200)}`;
    console.log(`FAIL: ${reason}`);
    return { passed: false, details: reason };
  }

  const failures: string[] = [];
  const v = scenario.validations ?? {};

  if (v.shouldNotBeEmpty !== false && !result.output.trim()) {
    failures.push('Response is empty');
  }

  if (v.shouldContain) {
    for (const expected of v.shouldContain) {
      if (!result.output.includes(expected)) {
        failures.push(`Missing expected content: "${expected}"`);
      }
    }
  }

  if (v.shouldMatchPattern && !v.shouldMatchPattern.test(result.output)) {
    failures.push(`Output did not match pattern: ${v.shouldMatchPattern}`);
  }

  if (failures.length > 0) {
    console.log(`FAIL: ${failures.join('; ')}`);
    return { passed: false, details: failures.join('; ') };
  }

  console.log(`PASS (${result.durationMs}ms)`);
  return { passed: true, details: `Completed in ${result.durationMs}ms` };
}

export async function runTestMatrix(
  providers: Provider[],
  scenarios: TestScenario[],
  config: Partial<CLITestConfig> = {}
): Promise<{ provider: string; scenario: string; passed: boolean; details: string }[]> {
  const results: { provider: string; scenario: string; passed: boolean; details: string }[] = [];

  for (const provider of providers) {
    if (!isProviderAvailable(provider)) {
      console.log(`\nSkipping ${provider}: CLI not available`);
      for (const scenario of scenarios) {
        results.push({
          provider,
          scenario: scenario.name,
          passed: false,
          details: 'Provider CLI not available',
        });
      }
      continue;
    }

    for (const scenario of scenarios) {
      const result = await runTestScenario(provider, scenario, config);
      results.push({
        provider,
        scenario: scenario.name,
        ...result,
      });
    }
  }

  return results;
}
