/**
 * Main entry point for the Ahuofe v2 pipeline.
 * CLI arg parsing and stage dispatch.
 */
import { loadConfig, resolveBrandPath } from "./config.js";
import { loadEntity, loadSharedConfig, loadPreset } from "./stages/load-yaml.js";
import { compilePrompt } from "./stages/compile-prompt.js";
import { runLoop } from "./stages/loop.js";
import type { Stage } from "./types.js";

interface CliOptions {
  config: string;
  stage: Stage;
  entity: string;
  brand?: string;
  output: string;
  pose?: string;
  ephemeral: boolean;
}

function parseCliArgs(args: string[]): CliOptions {
  const opts: Partial<CliOptions> = { ephemeral: false };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--config":
        opts.config = args[++i];
        break;
      case "--stage":
        opts.stage = args[++i] as Stage;
        break;
      case "--entity":
        opts.entity = args[++i];
        break;
      case "--brand":
        opts.brand = args[++i];
        break;
      case "--output":
        opts.output = args[++i];
        break;
      case "--pose":
        opts.pose = args[++i];
        break;
      case "--ephemeral":
        opts.ephemeral = true;
        break;
      case "--help":
      case "-h":
        printHelp();
        process.exit(0);
    }
  }

  if (!opts.config) {
    console.error("Error: --config <path> is required");
    process.exit(1);
  }
  if (!opts.stage) {
    console.error("Error: --stage <draft|review|refine|final> is required");
    process.exit(1);
  }
  if (!opts.entity) {
    console.error("Error: --entity <name> is required");
    process.exit(1);
  }

  return {
    config: opts.config!,
    stage: opts.stage!,
    entity: opts.entity!,
    brand: opts.brand,
    output: opts.output ?? "./generations",
    pose: opts.pose,
    ephemeral: opts.ephemeral ?? false,
  };
}

function printHelp(): void {
  console.log(`
Ahuofe v2 Pipeline — Generation Engine

Usage:
  npx tsx src/index.ts --config <path> --stage <stage> --entity <name> [options]

Required:
  --config <path>       Path to .ahuofe.yaml config file
  --stage <stage>       Generation stage: draft, review, refine, final
  --entity <name>       Entity ID to generate

Options:
  --brand <path>        Override brand directory path
  --output <path>       Output directory (default: ./generations)
  --pose <pose-id>      Specific pose to generate
  --ephemeral           Enforce fal.ai retention headers + post-download deletion
  --help, -h            Show this help

Examples:
  npx tsx src/index.ts --config .ahuofe.yaml --stage draft --entity okyeame
  npx tsx src/index.ts --config .ahuofe.yaml --stage final --entity okyeame --pose idle-standing --ephemeral
`);
}

async function main(): Promise<void> {
  const opts = parseCliArgs(process.argv.slice(2));
  const config = loadConfig(opts.config);

  const brandPath = opts.brand
    ? opts.brand
    : resolveBrandPath(opts.config, config.brand_path);

  console.log(`Ahuofe Pipeline — ${opts.stage.toUpperCase()} stage`);
  console.log(`Entity: ${opts.entity}`);
  console.log(`Brand path: ${brandPath}`);
  console.log(`Output: ${opts.output}`);
  console.log("");

  // Stage dispatch
  if (opts.stage === "draft" || opts.stage === "review" || opts.stage === "final") {
    // Load preset for this stage
    let preset;
    try {
      preset = loadPreset(brandPath, opts.stage);
    } catch {
      // Use config defaults if no preset file
      preset = {
        name: opts.stage,
        model: config.fal.models[opts.stage as keyof typeof config.fal.models] ?? config.fal.models.draft,
        reference_sheet: opts.stage === "final",
        max_iterations: opts.stage === "final" ? config.defaults.max_iterations : 1,
        pass_threshold: config.defaults.pass_threshold,
        drift_evaluation: (opts.stage === "final" ? "vision" : "quick") as "quick" | "vision",
        output_format: (opts.stage === "final" ? "png" : "jpg") as "png" | "jpg",
        aspect_ratio: "16:9",
        requires_approval: opts.stage !== "draft",
      };
    }

    const entity = loadEntity(brandPath, opts.entity);
    const shared = loadSharedConfig(brandPath);

    if (opts.stage === "draft" as string) {
      // For draft, just compile and show the prompt (if no API key)
      if (!process.env.FAL_KEY) {
        const prompt = compilePrompt(entity, shared, opts.pose);
        console.log("Compiled prompt (draft mode, no FAL_KEY):");
        console.log(prompt.main_prompt);
        return;
      }
    }

    const result = await runLoop({
      entity,
      shared,
      config,
      preset,
      stage: opts.stage as Stage,
      outputDir: opts.output,
      poseId: opts.pose,
    });

    console.log(`\nGeneration complete — ${result.iterations} iteration(s)`);
    console.log(`Passed: ${result.passed}`);
    console.log(`Final drift score: ${result.final_drift.score}`);
  } else {
    console.error(`Unknown stage: ${opts.stage}`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(`Pipeline error: ${(err as Error).message}`);
  process.exit(1);
});
