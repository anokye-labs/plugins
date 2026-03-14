/**
 * Transform entity YAML into generation prompts with drift checklists,
 * negative constraints, and NOT_THIS guards.
 */
import type {
  BrandEntity,
  SharedConfig,
  CompiledPrompt,
  DriftCheck,
} from "../types.js";

/**
 * Compile a full generation prompt from an entity and shared config.
 */
export function compilePrompt(
  entity: BrandEntity,
  shared: SharedConfig,
  poseId?: string,
): CompiledPrompt {
  const pose = poseId
    ? entity.poses?.find((p) => p.id === poseId)
    : entity.poses?.[0];

  const mainPrompt = buildMainPrompt(entity, shared, pose);
  const negativePrompt = buildNegativePrompt(entity, shared);
  const driftChecklist = buildDriftChecklist(entity, shared);
  const notThisGuards = entity.not_this ?? [];

  return {
    entity_id: entity.id,
    pose_id: pose?.id,
    main_prompt: mainPrompt,
    negative_prompt: negativePrompt,
    drift_checklist: driftChecklist,
    not_this_guards: notThisGuards,
    char_count: mainPrompt.length + negativePrompt.length,
  };
}

/**
 * Build the main positive prompt from entity properties.
 */
function buildMainPrompt(
  entity: BrandEntity,
  shared: SharedConfig,
  pose?: { id: string; name: string; description: string; camera_angle?: string },
): string {
  const parts: string[] = [];

  // Entity identity
  parts.push(`${entity.name}, ${entity.base_form}`);

  // Class context
  if (entity.class) {
    parts.push(`Character class: ${entity.class}`);
  }

  // Pose description
  if (pose) {
    parts.push(`Pose: ${pose.name} — ${pose.description}`);
    if (pose.camera_angle) {
      parts.push(`Camera angle: ${pose.camera_angle}`);
    }
  }

  // Body parts with detail
  if (entity.body_parts) {
    const bodyDesc = Object.entries(entity.body_parts)
      .map(([name, spec]) => {
        let desc = `${name}: ${spec.description}`;
        if (spec.material && shared.materials?.[spec.material]) {
          desc += ` (${shared.materials[spec.material].description})`;
        }
        if (spec.color_ref) {
          desc += ` [color: ${spec.color_ref}]`;
        }
        return desc;
      })
      .join(". ");
    parts.push(bodyDesc);
  }

  // Proportions
  if (entity.proportions) {
    const propDesc = Object.entries(entity.proportions)
      .map(([k, v]) => `${k}: ${v}`)
      .join(", ");
    parts.push(`Proportions: ${propDesc}`);
  }

  // Adinkra reference
  if (entity.adinkra_ref && shared.adinkra_map?.[entity.adinkra_ref]) {
    const adinkra = shared.adinkra_map[entity.adinkra_ref];
    parts.push(
      `Adinkra symbol: ${adinkra.name} (${adinkra.meaning})${adinkra.rendering ? ` — ${adinkra.rendering}` : ""}`,
    );
  }

  // Environment
  if (shared.environment) {
    const env = shared.environment;
    const envParts: string[] = [];
    if (env.lighting) envParts.push(`Lighting: ${env.lighting}`);
    if (env.background) envParts.push(`Background: ${env.background}`);
    if (env.atmosphere) envParts.push(`Atmosphere: ${env.atmosphere}`);
    if (envParts.length > 0) parts.push(envParts.join(". "));
  }

  // Drift checklist as embedded instructions
  parts.push("CRITICAL CONSISTENCY REQUIREMENTS:");
  const checks = buildDriftChecklist(entity, shared);
  for (const check of checks) {
    parts.push(`- MUST: ${check.name}`);
  }

  // NOT_THIS guards
  if (entity.not_this && entity.not_this.length > 0) {
    parts.push("NOT_THIS (avoid these specifically):");
    for (const guard of entity.not_this) {
      parts.push(`- DO NOT: ${guard}`);
    }
  }

  return parts.join(". ");
}

/**
 * Build the negative prompt from entity constraints and shared config.
 */
function buildNegativePrompt(
  entity: BrandEntity,
  shared: SharedConfig,
): string {
  const negatives: string[] = [];

  // Standard quality negatives
  negatives.push(
    "blurry",
    "low quality",
    "distorted",
    "deformed",
    "watermark",
    "text overlay",
    "signature",
  );

  // Entity-specific NOT_THIS as negatives
  if (entity.not_this) {
    negatives.push(...entity.not_this);
  }

  // Body-part constraint violations
  if (entity.body_parts) {
    for (const [, spec] of Object.entries(entity.body_parts)) {
      if (spec.constraints) {
        negatives.push(...spec.constraints);
      }
    }
  }

  // Differentiation matrix: ensure this entity doesn't look like others
  if (shared.differentiation_matrix?.[entity.id]) {
    const diffs = shared.differentiation_matrix[entity.id];
    for (const [, diffDesc] of Object.entries(diffs)) {
      negatives.push(diffDesc);
    }
  }

  return negatives.join(", ");
}

/**
 * Build a drift checklist from entity body parts and properties.
 */
function buildDriftChecklist(
  entity: BrandEntity,
  shared: SharedConfig,
): DriftCheck[] {
  const checks: DriftCheck[] = [];

  // Check base form
  checks.push({
    name: `Base form is: ${entity.base_form}`,
    status: "unknown",
  });

  // Check each body part
  if (entity.body_parts) {
    for (const [partName, spec] of Object.entries(entity.body_parts)) {
      checks.push({
        name: `${partName}: ${spec.description}`,
        status: "unknown",
      });

      if (spec.material) {
        checks.push({
          name: `${partName} material: ${spec.material}`,
          status: "unknown",
        });
      }
    }
  }

  // Check adinkra
  if (entity.adinkra_ref && shared.adinkra_map?.[entity.adinkra_ref]) {
    checks.push({
      name: `Adinkra symbol: ${shared.adinkra_map[entity.adinkra_ref].name} present`,
      status: "unknown",
    });
  }

  // Check proportions
  if (entity.proportions) {
    for (const [prop, val] of Object.entries(entity.proportions)) {
      checks.push({
        name: `Proportion ${prop}: ${val}`,
        status: "unknown",
      });
    }
  }

  return checks;
}
