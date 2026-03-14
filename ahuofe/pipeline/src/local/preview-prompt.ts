/**
 * Compile and display prompts locally from YAML.
 * Shows what would be sent to fal.ai, without making any API calls.
 * Works entirely offline — no API keys required.
 */
import { resolve } from "node:path";
import { loadEntity, loadSharedConfig } from "../stages/load-yaml.js";
import { compilePrompt } from "../stages/compile-prompt.js";
import type { CompiledPrompt } from "../types.js";

export interface PreviewResult {
  prompt: CompiledPrompt;
  formatted: string;
}

/**
 * Preview the compiled prompt for an entity.
 */
export function previewPrompt(
  brandPath: string,
  entityId: string,
  poseId?: string,
): PreviewResult {
  const absBrandPath = resolve(brandPath);
  const entity = loadEntity(absBrandPath, entityId);
  const shared = loadSharedConfig(absBrandPath);
  const prompt = compilePrompt(entity, shared, poseId);

  const formatted = formatPrompt(prompt);
  return { prompt, formatted };
}

/**
 * Format a compiled prompt for display.
 */
export function formatPrompt(prompt: CompiledPrompt): string {
  const lines: string[] = [];

  lines.push("=".repeat(70));
  lines.push(`ENTITY: ${prompt.entity_id}${prompt.pose_id ? ` (pose: ${prompt.pose_id})` : ""}`);
  lines.push("=".repeat(70));

  lines.push("");
  lines.push("--- MAIN PROMPT ---");
  lines.push(prompt.main_prompt);

  lines.push("");
  lines.push("--- NEGATIVE PROMPT ---");
  lines.push(prompt.negative_prompt);

  lines.push("");
  lines.push("--- DRIFT CHECKLIST ---");
  for (const check of prompt.drift_checklist) {
    lines.push(`  [ ] ${check.name}`);
  }

  if (prompt.not_this_guards.length > 0) {
    lines.push("");
    lines.push("--- NOT_THIS GUARDS ---");
    for (const guard of prompt.not_this_guards) {
      lines.push(`  x  ${guard}`);
    }
  }

  lines.push("");
  lines.push(`Character count: ${prompt.char_count}`);
  lines.push(`Estimated tokens: ~${Math.ceil(prompt.char_count / 4)}`);
  lines.push("=".repeat(70));

  return lines.join("\n");
}

/**
 * CLI entry point.
 */
export function main(args: string[] = process.argv.slice(2)): void {
  if (args.includes("--help") || args.includes("-h")) {
    console.log(`
Usage: npx tsx src/local/preview-prompt.ts [options]

Options:
  --brand <path>    Path to brand directory (required)
  --entity <name>   Entity to preview (required)
  --pose <pose-id>  Specific pose to preview (optional)
  --show-drift      Show drift checklist details
  --help, -h        Show this help

Examples:
  npx tsx src/local/preview-prompt.ts --brand ./brand --entity okyeame
  npx tsx src/local/preview-prompt.ts --brand ./brand --entity okyeame --pose idle-standing
`);
    return;
  }

  const brandIdx = args.indexOf("--brand");
  const entityIdx = args.indexOf("--entity");
  const poseIdx = args.indexOf("--pose");

  if (brandIdx === -1 || entityIdx === -1) {
    console.error("Error: --brand <path> and --entity <name> are required");
    process.exitCode = 1;
    return;
  }

  const brandPath = args[brandIdx + 1];
  const entityId = args[entityIdx + 1];
  const poseId = poseIdx !== -1 ? args[poseIdx + 1] : undefined;

  try {
    const result = previewPrompt(brandPath, entityId, poseId);
    console.log(result.formatted);
  } catch (err) {
    console.error(`Error: ${(err as Error).message}`);
    process.exitCode = 1;
  }
}

// Run if called directly
const isMain = process.argv[1]?.includes("preview-prompt");
if (isMain) {
  main();
}
