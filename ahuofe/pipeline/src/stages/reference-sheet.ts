/**
 * Generate character reference sheets via fal.ai kontext model.
 */
import type { BrandEntity, SharedConfig, PipelineConfig, FalImage } from "../types.js";
import { generateEphemeral } from "../fal/client.js";

export interface ReferenceSheetResult {
  entity_id: string;
  image_path: string;
  image: FalImage;
  seed?: number;
}

/**
 * Generate a reference sheet for an entity using the kontext model.
 * The reference sheet shows the entity from multiple angles for consistency.
 */
export async function generateReferenceSheet(
  entity: BrandEntity,
  shared: SharedConfig,
  config: PipelineConfig,
  outputDir: string,
): Promise<ReferenceSheetResult> {
  const model = config.fal.models.reference;

  const prompt = buildReferencePrompt(entity, shared);

  const result = await generateEphemeral(model, {
    prompt,
    num_images: 1,
    aspect_ratio: "16:9",
  }, config.fal);

  if (!result.images || result.images.length === 0) {
    throw new Error(
      `Reference sheet generation failed for ${entity.id}: no images returned`,
    );
  }

  const image = result.images[0];
  const imagePath = `${outputDir}/${entity.id}-reference-sheet.png`;

  return {
    entity_id: entity.id,
    image_path: imagePath,
    image,
    seed: result.seed,
  };
}

/**
 * Build a prompt specifically for reference sheet generation.
 */
function buildReferencePrompt(
  entity: BrandEntity,
  shared: SharedConfig,
): string {
  const parts: string[] = [];

  parts.push(
    `Character reference sheet for ${entity.name}, ${entity.base_form}`,
  );
  parts.push("Multiple angles: front view, 3/4 view, side view, back view");
  parts.push("Clean white background, consistent lighting, turnaround sheet");

  if (entity.body_parts) {
    const keyParts = Object.entries(entity.body_parts)
      .slice(0, 5)
      .map(([name, spec]) => `${name}: ${spec.description}`)
      .join("; ");
    parts.push(`Key features: ${keyParts}`);
  }

  if (entity.proportions) {
    const propDesc = Object.entries(entity.proportions)
      .map(([k, v]) => `${k}: ${v}`)
      .join(", ");
    parts.push(`Proportions: ${propDesc}`);
  }

  if (shared.environment?.lighting) {
    parts.push(`Reference lighting: ${shared.environment.lighting}`);
  }

  return parts.join(". ");
}
