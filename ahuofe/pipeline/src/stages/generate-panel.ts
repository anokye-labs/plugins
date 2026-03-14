/**
 * Generate individual panels/images using compiled prompts.
 */
import type {
  CompiledPrompt,
  PipelineConfig,
  GenerationResult,
  Stage,
  FalImage,
} from "../types.js";
import { generateEphemeral } from "../fal/client.js";

export interface GeneratePanelOptions {
  prompt: CompiledPrompt;
  config: PipelineConfig;
  stage: Stage;
  outputDir: string;
  seed?: number;
  referenceImageUrl?: string;
}

/**
 * Generate a single panel image from a compiled prompt.
 */
export async function generatePanel(
  options: GeneratePanelOptions,
): Promise<GenerationResult> {
  const { prompt, config, stage, outputDir, seed, referenceImageUrl } = options;

  const model = config.fal.models[stage as keyof typeof config.fal.models];
  if (!model) {
    throw new Error(`No model configured for stage: ${stage}`);
  }

  const input: Record<string, unknown> = {
    prompt: prompt.main_prompt,
    num_images: 1,
    aspect_ratio: "16:9",
  };

  if (prompt.negative_prompt) {
    input.negative_prompt = prompt.negative_prompt;
  }

  if (seed !== undefined) {
    input.seed = seed;
  }

  if (referenceImageUrl) {
    input.image_url = referenceImageUrl;
  }

  const result = await generateEphemeral(model, input, config.fal);

  if (!result.images || result.images.length === 0) {
    throw new Error(
      `Generation failed for ${prompt.entity_id}: no images returned`,
    );
  }

  const image: FalImage = result.images[0];
  const timestamp = new Date().toISOString();
  const genId = `gen-${Date.now()}`;
  const filename = `${prompt.entity_id}${prompt.pose_id ? `-${prompt.pose_id}` : ""}-${stage}.${stage === "final" ? "png" : "jpg"}`;
  const imagePath = `${outputDir}/${filename}`;

  return {
    id: genId,
    entity_id: prompt.entity_id,
    pose_id: prompt.pose_id,
    stage: stage as Stage,
    model,
    image_path: imagePath,
    seed: result.seed,
    width: image.width,
    height: image.height,
    prompt: prompt.main_prompt,
    timestamp,
  };
}
