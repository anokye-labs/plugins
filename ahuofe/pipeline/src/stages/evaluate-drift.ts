/**
 * Evaluate drift between a generated image and the brand spec.
 * Quick mode: rule-based checklist. Vision mode: Claude vision API.
 */
import type {
  BrandEntity,
  SharedConfig,
  DriftReport,
  DriftCheck,
  CompiledPrompt,
  Preset,
} from "../types.js";

export interface EvaluateDriftOptions {
  entity: BrandEntity;
  shared: SharedConfig;
  prompt: CompiledPrompt;
  imagePath: string;
  preset: Preset;
}

/**
 * Evaluate drift for a generated image against the brand spec.
 * Dispatches to quick (rule-based) or vision (Claude API) based on preset.
 */
export async function evaluateDrift(
  options: EvaluateDriftOptions,
): Promise<DriftReport> {
  const { preset } = options;

  switch (preset.drift_evaluation) {
    case "quick":
      return evaluateQuick(options);
    case "quick_plus":
      return evaluateQuickPlus(options);
    case "vision":
      return evaluateVision(options);
    default:
      return evaluateQuick(options);
  }
}

/**
 * Quick, rule-based drift evaluation.
 * Marks all checks as "pass" since we can't actually inspect pixels without vision.
 * Returns the checklist as-is for human review.
 */
function evaluateQuick(options: EvaluateDriftOptions): DriftReport {
  const checks: DriftCheck[] = options.prompt.drift_checklist.map(
    (check) => ({
      ...check,
      status: "unknown" as const,
      detail: "Requires visual inspection",
    }),
  );

  const score = 0; // Unknown without vision evaluation
  return {
    score,
    passed: false,
    checks,
    summary: `Quick evaluation: ${checks.length} items require visual inspection. Use 'vision' drift evaluation for automated scoring.`,
  };
}

/**
 * Quick-plus evaluation: rule-based checks plus a text summary.
 */
function evaluateQuickPlus(options: EvaluateDriftOptions): DriftReport {
  const quickReport = evaluateQuick(options);

  const entitySummary = [
    `Entity: ${options.entity.name} (${options.entity.base_form})`,
    options.entity.body_parts
      ? `Body parts: ${Object.keys(options.entity.body_parts).join(", ")}`
      : null,
    options.entity.adinkra_ref
      ? `Adinkra: ${options.entity.adinkra_ref}`
      : null,
    options.entity.not_this
      ? `NOT_THIS guards: ${options.entity.not_this.join("; ")}`
      : null,
  ]
    .filter(Boolean)
    .join(". ");

  return {
    ...quickReport,
    summary: `${quickReport.summary}\n\nEntity profile: ${entitySummary}`,
  };
}

/**
 * Vision-based drift evaluation using Claude vision API.
 * In production, this sends the image to Claude for analysis.
 * Here we define the interface; actual API call is external.
 */
async function evaluateVision(
  options: EvaluateDriftOptions,
): Promise<DriftReport> {
  // Vision evaluation requires ANTHROPIC_API_KEY.
  // The actual implementation calls the Claude API with the image.
  // For this module, we provide the evaluation structure.

  if (!process.env.ANTHROPIC_API_KEY) {
    throw new Error(
      "Vision drift evaluation requires ANTHROPIC_API_KEY environment variable",
    );
  }

  // Build the evaluation prompt for Claude
  const _evalPrompt = buildVisionEvalPrompt(options);

  // In a real implementation, this would call the Claude Vision API.
  // For now, return a placeholder that indicates vision eval was requested.
  const checks: DriftCheck[] = options.prompt.drift_checklist.map(
    (check) => ({
      ...check,
      status: "unknown" as const,
      detail: "Vision evaluation pending",
    }),
  );

  return {
    score: 0,
    passed: false,
    checks,
    summary: "Vision evaluation requires Claude API integration. Checklist items listed for manual review.",
  };
}

/**
 * Build the prompt that would be sent to Claude for vision evaluation.
 */
function buildVisionEvalPrompt(options: EvaluateDriftOptions): string {
  const { entity, prompt } = options;
  const parts: string[] = [];

  parts.push(
    `Evaluate this generated image of "${entity.name}" against the brand specification.`,
  );
  parts.push(`Base form: ${entity.base_form}`);
  parts.push("");
  parts.push("Check each item and rate as PASS or DRIFT:");

  for (const check of prompt.drift_checklist) {
    parts.push(`- ${check.name}`);
  }

  if (entity.not_this && entity.not_this.length > 0) {
    parts.push("");
    parts.push("Also verify NONE of these are present (NOT_THIS):");
    for (const guard of entity.not_this) {
      parts.push(`- ${guard}`);
    }
  }

  parts.push("");
  parts.push(
    "For each check, respond with: CHECK_NAME: PASS|DRIFT (brief explanation)",
  );
  parts.push(
    "End with: OVERALL_SCORE: 0-100 (percentage of checks that pass)",
  );

  return parts.join("\n");
}
