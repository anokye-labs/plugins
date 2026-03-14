/**
 * Orchestrate the generate-evaluate-refine loop with configurable
 * max iterations and pass threshold.
 */
import type {
  BrandEntity,
  SharedConfig,
  PipelineConfig,
  Preset,
  Stage,
  GenerationResult,
  DriftReport,
  CompiledPrompt,
} from "../types.js";
import { compilePrompt } from "./compile-prompt.js";
import { generatePanel } from "./generate-panel.js";
import { evaluateDrift } from "./evaluate-drift.js";
import { generateReferenceSheet } from "./reference-sheet.js";

export interface LoopOptions {
  entity: BrandEntity;
  shared: SharedConfig;
  config: PipelineConfig;
  preset: Preset;
  stage: Stage;
  outputDir: string;
  poseId?: string;
}

export interface LoopResult {
  entity_id: string;
  stage: Stage;
  iterations: number;
  final_result: GenerationResult;
  final_drift: DriftReport;
  passed: boolean;
  reference_image?: string;
  all_results: Array<{
    iteration: number;
    result: GenerationResult;
    drift: DriftReport;
  }>;
}

/**
 * Run the generate-evaluate loop until the drift score passes
 * or max iterations are reached.
 */
export async function runLoop(options: LoopOptions): Promise<LoopResult> {
  const {
    entity,
    shared,
    config,
    preset,
    stage,
    outputDir,
    poseId,
  } = options;

  const maxIterations = preset.max_iterations;
  const passThreshold = preset.pass_threshold ?? config.defaults.pass_threshold;

  // Generate reference sheet if required by preset
  let referenceImageUrl: string | undefined;
  if (preset.reference_sheet) {
    const refResult = await generateReferenceSheet(
      entity,
      shared,
      config,
      outputDir,
    );
    referenceImageUrl = refResult.image.url;
  }

  const prompt: CompiledPrompt = compilePrompt(entity, shared, poseId);

  const allResults: LoopResult["all_results"] = [];
  let finalResult: GenerationResult | null = null;
  let finalDrift: DriftReport | null = null;
  let passed = false;

  for (let i = 0; i < maxIterations; i++) {
    // Generate
    const result = await generatePanel({
      prompt,
      config,
      stage,
      outputDir,
      referenceImageUrl,
    });

    // Evaluate drift
    const drift = await evaluateDrift({
      entity,
      shared,
      prompt,
      imagePath: result.image_path,
      preset,
    });

    result.drift_score = drift.score;
    result.drift_report = drift;

    allResults.push({ iteration: i + 1, result, drift });
    finalResult = result;
    finalDrift = drift;

    // Check if passed
    if (drift.score >= passThreshold) {
      passed = true;
      break;
    }
  }

  return {
    entity_id: entity.id,
    stage,
    iterations: allResults.length,
    final_result: finalResult!,
    final_drift: finalDrift!,
    passed,
    reference_image: referenceImageUrl,
    all_results: allResults,
  };
}
