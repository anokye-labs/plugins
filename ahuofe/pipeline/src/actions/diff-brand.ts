/**
 * Given a git diff, detect which brand entity YAML files changed
 * and which entities are affected.
 */
import { basename } from "node:path";

export interface DiffResult {
  changedFiles: string[];
  affectedEntities: string[];
  hasSharedChanges: boolean;
}

/**
 * Parse git diff output to find changed brand entity files.
 *
 * @param diffOutput - Output from `git diff --name-only base..head`
 * @param brandPath - Relative brand directory path (e.g., "brand/")
 */
export function parseBrandDiff(
  diffOutput: string,
  brandPath: string,
): DiffResult {
  const normalizedBrandPath = brandPath.replace(/\\/g, "/").replace(/\/$/, "");
  const lines = diffOutput
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  const changedFiles: string[] = [];
  const affectedEntities = new Set<string>();
  let hasSharedChanges = false;

  for (const line of lines) {
    const normalizedLine = line.replace(/\\/g, "/");

    // Check if this file is under the brand path
    if (!normalizedLine.startsWith(normalizedBrandPath + "/")) {
      continue;
    }

    changedFiles.push(line);

    // Relative path within brand/
    const relPath = normalizedLine.slice(normalizedBrandPath.length + 1);

    // Check if it's a shared file
    if (relPath.startsWith("shared/")) {
      hasSharedChanges = true;
      continue;
    }

    // Check if it's a preset file
    if (relPath.startsWith("presets/")) {
      continue;
    }

    // Check if it's an entity file
    if (relPath.startsWith("entities/") && (relPath.endsWith(".yaml") || relPath.endsWith(".yml"))) {
      const entityName = basename(relPath, relPath.endsWith(".yaml") ? ".yaml" : ".yml");
      affectedEntities.add(entityName);
    }
  }

  // If shared files changed, ALL entities are potentially affected
  // but we still only list the directly changed ones — the caller
  // can decide whether to regenerate all entities based on hasSharedChanges.

  return {
    changedFiles,
    affectedEntities: Array.from(affectedEntities),
    hasSharedChanges,
  };
}

/**
 * Format diff result as GitHub Actions output.
 */
export function formatAsActionsOutput(result: DiffResult): string {
  const lines: string[] = [];
  lines.push(`entities=${JSON.stringify(result.affectedEntities)}`);
  lines.push(`has_shared_changes=${result.hasSharedChanges}`);
  lines.push(`changed_files=${JSON.stringify(result.changedFiles)}`);

  // If there are entities or shared changes, there's work to do
  const hasWork =
    result.affectedEntities.length > 0 || result.hasSharedChanges;
  lines.push(`command=${hasWork ? "generate" : "none"}`);
  lines.push(`stage=draft`);
  lines.push(`requires_approval=false`);

  return lines.join("\n");
}
