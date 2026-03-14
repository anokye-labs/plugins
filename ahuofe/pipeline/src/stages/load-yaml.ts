/**
 * Load entity YAML + shared YAML, merge inherited properties, validate.
 */
import { readFileSync, existsSync } from "node:fs";
import { resolve, join } from "node:path";
import yaml from "js-yaml";
import type { BrandEntity, SharedConfig, Preset } from "../types.js";

/**
 * Load a brand entity from a YAML file.
 * Searches in brand_path/entities/ recursively for `{entityId}.yaml`.
 */
export function loadEntity(
  brandPath: string,
  entityId: string,
): BrandEntity {
  const entitiesDir = resolve(brandPath, "entities");
  const candidatePaths = [
    join(entitiesDir, `${entityId}.yaml`),
    join(entitiesDir, "physical", `${entityId}.yaml`),
    join(entitiesDir, "virtual", `${entityId}.yaml`),
    join(entitiesDir, "collective", `${entityId}.yaml`),
  ];

  for (const p of candidatePaths) {
    if (existsSync(p)) {
      const raw = readFileSync(p, "utf-8");
      const parsed = yaml.load(raw) as Record<string, unknown>;
      if (!parsed || typeof parsed !== "object") {
        throw new Error(`Invalid entity YAML at ${p}: expected object`);
      }
      return validateEntity(parsed, p);
    }
  }

  throw new Error(
    `Entity not found: ${entityId} — searched in ${entitiesDir}`,
  );
}

/**
 * Load shared configuration from brand/shared/ directory.
 */
export function loadSharedConfig(brandPath: string): SharedConfig {
  const sharedDir = resolve(brandPath, "shared");
  const shared: SharedConfig = {};

  const files: Array<{ name: string; key: keyof SharedConfig }> = [
    { name: "colors.yaml", key: "colors" },
    { name: "materials.yaml", key: "materials" },
    { name: "environment.yaml", key: "environment" },
    { name: "proportions.yaml", key: "proportions" },
    { name: "adinkra-map.yaml", key: "adinkra_map" },
    { name: "differentiation-matrix.yaml", key: "differentiation_matrix" },
  ];

  for (const file of files) {
    const filePath = join(sharedDir, file.name);
    if (existsSync(filePath)) {
      const raw = readFileSync(filePath, "utf-8");
      const parsed = yaml.load(raw);
      if (parsed != null) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (shared as any)[file.key] = parsed;
      }
    }
  }

  return shared;
}

/**
 * Load a preset configuration from brand/presets/ directory.
 */
export function loadPreset(brandPath: string, presetName: string): Preset {
  const presetsDir = resolve(brandPath, "presets");
  const presetPath = join(presetsDir, `${presetName}.yaml`);

  if (!existsSync(presetPath)) {
    throw new Error(`Preset not found: ${presetName} at ${presetPath}`);
  }

  const raw = readFileSync(presetPath, "utf-8");
  const parsed = yaml.load(raw) as Record<string, unknown>;

  if (!parsed || typeof parsed !== "object") {
    throw new Error(`Invalid preset YAML at ${presetPath}: expected object`);
  }

  return {
    name: (parsed.name as string) ?? presetName,
    model: parsed.model as string,
    reference_sheet: (parsed.reference_sheet as boolean) ?? false,
    reference_model: parsed.reference_model as string | undefined,
    max_iterations: (parsed.max_iterations as number) ?? 1,
    pass_threshold: parsed.pass_threshold as number | undefined,
    drift_evaluation:
      (parsed.drift_evaluation as Preset["drift_evaluation"]) ?? "quick",
    output_format:
      (parsed.output_format as "jpg" | "png") ?? "jpg",
    quality: parsed.quality as number | undefined,
    aspect_ratio: (parsed.aspect_ratio as string) ?? "16:9",
    requires_approval: (parsed.requires_approval as boolean) ?? false,
  };
}

/**
 * Merge shared config properties into an entity (inherited fields).
 */
export function mergeSharedIntoEntity(
  entity: BrandEntity,
  shared: SharedConfig,
): BrandEntity {
  const merged = { ...entity };

  // Resolve color references in body parts
  if (merged.body_parts && shared.colors) {
    for (const [partName, part] of Object.entries(merged.body_parts)) {
      if (part.color_ref && shared.colors[part.color_ref]) {
        merged.body_parts[partName] = {
          ...part,
          color_ref: shared.colors[part.color_ref],
        };
      }
    }
  }

  // Merge proportions if not overridden
  if (!merged.proportions && shared.proportions) {
    merged.proportions = { ...shared.proportions };
  }

  return merged;
}

/**
 * Validate that an entity has required fields.
 */
function validateEntity(
  data: Record<string, unknown>,
  filePath: string,
): BrandEntity {
  if (!data.id && !data.name) {
    throw new Error(
      `Invalid entity at ${filePath}: must have at least 'id' or 'name'`,
    );
  }

  if (!data.base_form) {
    throw new Error(
      `Invalid entity at ${filePath}: missing required field 'base_form'`,
    );
  }

  return {
    id: (data.id as string) ?? (data.name as string).toLowerCase().replace(/\s+/g, "-"),
    name: (data.name as string) ?? (data.id as string),
    class: data.class as string | undefined,
    base_form: data.base_form as string,
    proportions: data.proportions as Record<string, string> | undefined,
    body_parts: data.body_parts as Record<string, import("../types.js").BodyPartSpec> | undefined,
    adinkra_ref: data.adinkra_ref as string | undefined,
    poses: data.poses as import("../types.js").PoseSpec[] | undefined,
    not_this: data.not_this as string[] | undefined,
    metadata: data.metadata as Record<string, unknown> | undefined,
  };
}
