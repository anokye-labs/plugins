/**
 * Format and post generation results as PR comments with image galleries,
 * drift reports, and cost summaries.
 */
import type { GenerationResult, DriftReport, Stage } from "../types.js";

export interface PostResultsOptions {
  results: GenerationResult[];
  stage: Stage;
  pruned?: string[];
  costEstimate?: number;
}

/**
 * Format generation results as a Markdown PR comment.
 */
export function formatResultsComment(options: PostResultsOptions): string {
  const { results, stage, pruned, costEstimate } = options;
  const lines: string[] = [];

  if (results.length === 0) {
    return "No generation results to report.";
  }

  const first = results[0];
  const genId = first.id;

  lines.push(`## Generation Report -- ${genId}`);
  lines.push("");
  lines.push(`**Entity:** ${first.entity_id}`);
  if (first.pose_id) lines.push(`**Pose:** ${first.pose_id}`);
  lines.push(`**Stage:** ${stage.toUpperCase()}`);
  lines.push(`**Model:** ${first.model}`);
  if (costEstimate !== undefined) {
    lines.push(`**Cost:** ~$${costEstimate.toFixed(2)}`);
  }
  lines.push(
    `**fal.ai retention:** Ephemeral (expires in 1h, will be explicitly deleted)`,
  );
  lines.push("");

  // Image gallery
  lines.push("### Generated Images");
  lines.push("");
  for (const result of results) {
    const label = `${result.entity_id}${result.pose_id ? `-${result.pose_id}` : ""}-${result.stage}`;
    lines.push(`![${label}](${result.image_path})`);
    lines.push("");
    if (result.seed !== undefined) {
      lines.push(`*Seed: ${result.seed}*`);
    }
  }

  // Drift report
  const driftResults = results.filter((r) => r.drift_report);
  if (driftResults.length > 0) {
    lines.push("");
    lines.push("### Drift Report");
    for (const result of driftResults) {
      const drift = result.drift_report!;
      lines.push("");
      lines.push(formatDriftTable(drift));
      if (drift.summary) {
        lines.push("");
        lines.push(`> ${drift.summary}`);
      }
    }
  }

  // Pruned generations
  if (pruned && pruned.length > 0) {
    lines.push("");
    lines.push("### Pruned");
    for (const p of pruned) {
      lines.push(`- Removed: ${p}`);
    }
  }

  // Next steps
  lines.push("");
  lines.push("### Next Steps");
  const entityId = first.entity_id;
  if (stage === "draft") {
    lines.push(
      `- \`@ahuofe regenerate ${entityId}\` -- Re-roll with note`,
    );
    lines.push(
      `- \`@ahuofe review ${entityId}\` -- Escalate to review quality (requires approval)`,
    );
    lines.push(
      `- \`@ahuofe finalize ${entityId}\` -- Run full consistency loop (requires approval)`,
    );
  } else if (stage === "review") {
    lines.push(
      `- \`@ahuofe finalize ${entityId}\` -- Run full consistency loop (requires approval)`,
    );
    lines.push(
      `- \`@ahuofe regenerate ${entityId}\` -- Re-roll review quality`,
    );
  } else if (stage === "final") {
    lines.push(
      `- \`@ahuofe approve\` -- Approve for merge`,
    );
  }

  return lines.join("\n");
}

/**
 * Format a drift report as a Markdown table.
 */
export function formatDriftTable(drift: DriftReport): string {
  const lines: string[] = [];
  lines.push("| Check | Status |");
  lines.push("|-------|--------|");

  for (const check of drift.checks) {
    const statusIcon =
      check.status === "pass"
        ? "Pass"
        : check.status === "drift"
          ? "DRIFT"
          : "?";
    lines.push(`| ${check.name} | ${statusIcon} |`);
  }

  if (drift.score > 0) {
    lines.push("");
    lines.push(`**Drift Score:** ${drift.score}/100 (${drift.passed ? "PASSED" : "NEEDS WORK"})`);
  }

  return lines.join("\n");
}
