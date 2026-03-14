/**
 * Generate placeholder SVG/PNG images for layout testing without calling fal.ai.
 * Works entirely offline — no API keys required.
 */
import { writeFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve, join } from "node:path";
import type { BrandEntity, GenerationResult, Stage } from "../types.js";

export interface MockGenerateOptions {
  entity: BrandEntity;
  poseId?: string;
  stage?: Stage;
  width?: number;
  height?: number;
  outputDir: string;
}

export interface MockGenerateResult {
  result: GenerationResult;
  svgContent: string;
}

/**
 * Generate a placeholder SVG image for an entity.
 * The SVG shows the entity name, pose, and stage for identification.
 */
export function mockGenerate(options: MockGenerateOptions): MockGenerateResult {
  const {
    entity,
    poseId,
    stage = "draft" as Stage,
    width = 1280,
    height = 720,
    outputDir,
  } = options;

  const pose = poseId
    ? entity.poses?.find((p) => p.id === poseId)
    : entity.poses?.[0];

  const poseName = pose?.name ?? poseId ?? "default";
  const filename = `${entity.id}${poseId ? `-${poseId}` : ""}-${stage}-mock.svg`;

  // Ensure output directory exists
  const absOutputDir = resolve(outputDir);
  if (!existsSync(absOutputDir)) {
    mkdirSync(absOutputDir, { recursive: true });
  }

  const svgContent = buildPlaceholderSvg({
    entityName: entity.name,
    entityId: entity.id,
    baseForm: entity.base_form,
    poseName,
    stage,
    width,
    height,
    bodyParts: entity.body_parts ? Object.keys(entity.body_parts) : [],
  });

  const filePath = join(absOutputDir, filename);
  writeFileSync(filePath, svgContent, "utf-8");

  const result: GenerationResult = {
    id: `mock-${Date.now()}`,
    entity_id: entity.id,
    pose_id: poseId,
    stage: stage as Stage,
    model: "mock-generator",
    image_path: filePath,
    width,
    height,
    prompt: `[MOCK] ${entity.name} - ${poseName}`,
    timestamp: new Date().toISOString(),
  };

  return { result, svgContent };
}

/**
 * Build a placeholder SVG with entity information.
 */
function buildPlaceholderSvg(opts: {
  entityName: string;
  entityId: string;
  baseForm: string;
  poseName: string;
  stage: string;
  width: number;
  height: number;
  bodyParts: string[];
}): string {
  const bgColor = {
    draft: "#2d3748",
    review: "#2c5282",
    refine: "#2f855a",
    final: "#744210",
  }[opts.stage] ?? "#2d3748";

  const bodyPartsList = opts.bodyParts
    .slice(0, 6)
    .map(
      (part, i) =>
        `<text x="50%" y="${opts.height / 2 + 60 + i * 22}" text-anchor="middle" font-family="monospace" font-size="14" fill="#a0aec0">${part}</text>`,
    )
    .join("\n    ");

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${opts.width}" height="${opts.height}" viewBox="0 0 ${opts.width} ${opts.height}">
  <rect width="100%" height="100%" fill="${bgColor}"/>
  <rect x="20" y="20" width="${opts.width - 40}" height="${opts.height - 40}" fill="none" stroke="#4a5568" stroke-width="2" stroke-dasharray="8,4" rx="8"/>
  <text x="50%" y="80" text-anchor="middle" font-family="sans-serif" font-size="36" font-weight="bold" fill="#e2e8f0">${opts.entityName}</text>
  <text x="50%" y="120" text-anchor="middle" font-family="monospace" font-size="16" fill="#a0aec0">${opts.entityId} | ${opts.baseForm}</text>
  <text x="50%" y="160" text-anchor="middle" font-family="sans-serif" font-size="20" fill="#63b3ed">Pose: ${opts.poseName}</text>
  <text x="50%" y="200" text-anchor="middle" font-family="monospace" font-size="14" fill="#fbd38d">Stage: ${opts.stage.toUpperCase()}</text>
  <line x1="30%" y1="230" x2="70%" y2="230" stroke="#4a5568" stroke-width="1"/>
  <text x="50%" y="${opts.height / 2 + 30}" text-anchor="middle" font-family="sans-serif" font-size="16" fill="#718096">Body Parts:</text>
  ${bodyPartsList}
  <text x="50%" y="${opts.height - 40}" text-anchor="middle" font-family="monospace" font-size="12" fill="#4a5568">MOCK PLACEHOLDER — ${opts.width}x${opts.height}</text>
</svg>`;
}
