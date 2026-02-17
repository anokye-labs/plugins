/**
 * Hybrid evaluation framework for plugin E2E tests.
 *
 * Two layers:
 *  1. Tool-call assertions — always run, deterministic, zero-cost
 *  2. LLM-as-judge — runs when EVAL_MODEL env var is set, provides semantic evaluation
 *
 * When no LLM is configured, tool-call assertions are the only gate.
 */

import { execFileSync } from 'child_process';

// ── Types ────────────────────────────────────────────────────────────

export interface EvalCriteria {
  /** Tool names that MUST have been called (hard fail) */
  requiredTools?: string[];
  /** Tool names that SHOULD NOT have been called */
  forbiddenTools?: string[];
  /** Semantic rubric for LLM judge — natural language description of what a good response looks like */
  rubric?: string;
  /** Minimum judge score (1-5) to pass. Default: 3 */
  minScore?: number;
}

export interface ToolCallResult {
  passed: boolean;
  missing: string[];
  forbidden: string[];
  called: string[];
}

export interface JudgeResult {
  passed: boolean;
  score: number;
  reasoning: string;
  skipped: boolean;
}

export interface EvalResult {
  passed: boolean;
  toolCalls: ToolCallResult;
  judge: JudgeResult;
}

// ── Tool-call assertions (always run) ────────────────────────────────

export function evaluateToolCalls(
  actualTools: string[],
  criteria: EvalCriteria
): ToolCallResult {
  const missing: string[] = [];
  const forbidden: string[] = [];

  if (criteria.requiredTools) {
    for (const tool of criteria.requiredTools) {
      if (!actualTools.includes(tool)) {
        missing.push(tool);
      }
    }
  }

  if (criteria.forbiddenTools) {
    for (const tool of criteria.forbiddenTools) {
      if (actualTools.includes(tool)) {
        forbidden.push(tool);
      }
    }
  }

  return {
    passed: missing.length === 0 && forbidden.length === 0,
    missing,
    forbidden,
    called: actualTools,
  };
}

// ── LLM-as-judge (when EVAL_MODEL is configured) ────────────────────

function getEvalModel(): string | null {
  return process.env.EVAL_MODEL || null;
}

/**
 * Calls the Copilot CLI in one-shot mode to judge a response.
 * Uses the model specified in EVAL_MODEL.
 */
async function callJudge(
  prompt: string,
  response: string,
  rubric: string,
  model: string
): Promise<{ score: number; reasoning: string }> {
  const judgePrompt = `You are an evaluation judge for an AI agent's response quality.

## Original Prompt
${prompt}

## Agent Response
${response}

## Evaluation Rubric
${rubric}

## Instructions
Score the response from 1 to 5:
- 1: Completely wrong or irrelevant
- 2: Partially addresses the prompt but major issues
- 3: Adequately addresses the prompt with minor issues
- 4: Good response that meets expectations
- 5: Excellent response that exceeds expectations

Respond in EXACTLY this JSON format (no markdown, no code fences):
{"score": <number>, "reasoning": "<one sentence>"}`;

  try {
    const result = execFileSync(
      'copilot',
      ['-p', judgePrompt, '-m', model, '-s', '--no-tools'],
      {
        encoding: 'utf-8',
        timeout: 60_000,
        env: { ...process.env },
      }
    );

    // Extract JSON from response (handle possible surrounding text)
    const jsonMatch = result.match(/\{[\s\S]*"score"[\s\S]*"reasoning"[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        score: Math.max(1, Math.min(5, Math.round(parsed.score))),
        reasoning: String(parsed.reasoning),
      };
    }

    return { score: 3, reasoning: 'Could not parse judge response' };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return { score: 0, reasoning: `Judge error: ${msg}` };
  }
}

export async function evaluateWithJudge(
  prompt: string,
  response: string,
  criteria: EvalCriteria
): Promise<JudgeResult> {
  const model = getEvalModel();

  if (!model || !criteria.rubric) {
    return { passed: true, score: 0, reasoning: 'LLM judge not configured', skipped: true };
  }

  const minScore = criteria.minScore ?? 3;
  const { score, reasoning } = await callJudge(prompt, response, criteria.rubric, model);

  return {
    passed: score >= minScore,
    score,
    reasoning,
    skipped: false,
  };
}

// ── Combined evaluation ──────────────────────────────────────────────

export async function evaluateTestResult(
  prompt: string,
  response: string,
  toolsCalled: string[],
  criteria: EvalCriteria
): Promise<EvalResult> {
  const toolCalls = evaluateToolCalls(toolsCalled, criteria);
  const judge = await evaluateWithJudge(prompt, response, criteria);

  // Overall: tool calls must pass. Judge must pass if it ran.
  const passed = toolCalls.passed && (judge.skipped || judge.passed);

  return { passed, toolCalls, judge };
}

// ── Reporting ────────────────────────────────────────────────────────

export function reportEvalResult(testName: string, result: EvalResult): void {
  console.log(`\n── Eval: ${testName} ──`);

  // Tool calls
  if (result.toolCalls.passed) {
    console.log(`  ✅ Tool calls: ${result.toolCalls.called.join(', ') || 'none'}`);
  } else {
    if (result.toolCalls.missing.length > 0) {
      console.log(`  ❌ Missing tools: ${result.toolCalls.missing.join(', ')}`);
    }
    if (result.toolCalls.forbidden.length > 0) {
      console.log(`  ❌ Forbidden tools called: ${result.toolCalls.forbidden.join(', ')}`);
    }
    console.log(`  📋 Tools called: ${result.toolCalls.called.join(', ') || 'none'}`);
  }

  // Judge
  if (result.judge.skipped) {
    console.log(`  ⏭️  LLM judge: skipped (set EVAL_MODEL to enable)`);
  } else if (result.judge.passed) {
    console.log(`  ✅ LLM judge: ${result.judge.score}/5 — ${result.judge.reasoning}`);
  } else {
    console.log(`  ❌ LLM judge: ${result.judge.score}/5 — ${result.judge.reasoning}`);
  }

  // Overall
  console.log(`  ${result.passed ? '✅' : '❌'} Overall: ${result.passed ? 'PASSED' : 'FAILED'}`);
}
