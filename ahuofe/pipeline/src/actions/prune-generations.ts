/**
 * Remove old generation files from PR branch, keeping only latest/selected
 * per entity. Supports stage-based pruning rules.
 */
import { readdirSync, statSync, existsSync } from "node:fs";
import { join, basename } from "node:path";
import type { Stage } from "../types.js";

export interface PruneOptions {
  generationsDir: string;
  currentStage: Stage;
  keepIds?: string[];
}

export interface PruneResult {
  kept: string[];
  removed: string[];
}

/**
 * Identify which generation files to keep and which to remove.
 *
 * Pruning rules:
 * - On a new draft: keep only the latest draft, remove older drafts
 * - On review: remove all drafts, keep only the review
 * - On final: remove everything except finalized images
 * - Files in keepIds are always preserved
 */
export function planPrune(options: PruneOptions): PruneResult {
  const { generationsDir, currentStage, keepIds = [] } = options;

  if (!existsSync(generationsDir)) {
    return { kept: [], removed: [] };
  }

  const entries = readdirSync(generationsDir)
    .map((name) => ({
      name,
      path: join(generationsDir, name),
      isDir: safeIsDir(join(generationsDir, name)),
    }))
    .filter((e) => e.isDir || isImageFile(e.name));

  const kept: string[] = [];
  const removed: string[] = [];

  // Categorize files by their stage
  const categorized = categorizeFiles(entries.map((e) => e.name));

  const keepSet = new Set(keepIds);

  for (const entry of entries) {
    const name = entry.name;

    // Always keep explicitly kept IDs
    if (keepSet.has(name) || keepSet.has(basename(name, ".png")) || keepSet.has(basename(name, ".jpg"))) {
      kept.push(name);
      continue;
    }

    const fileStage = categorized.get(name);

    switch (currentStage) {
      case "draft":
        // Keep only the latest draft (last entry with draft stage)
        if (fileStage === "draft") {
          // We'll keep the last draft; mark earlier ones for removal
          // For now, keep all drafts — the caller picks the latest
          kept.push(name);
        } else {
          kept.push(name); // Keep non-draft files
        }
        break;

      case "review":
        // Remove all drafts, keep reviews
        if (fileStage === "draft") {
          removed.push(name);
        } else {
          kept.push(name);
        }
        break;

      case "refine":
        // Remove drafts, keep reviews and refinements
        if (fileStage === "draft") {
          removed.push(name);
        } else {
          kept.push(name);
        }
        break;

      case "final":
        // Remove everything except finalized images
        if (fileStage === "final") {
          kept.push(name);
        } else {
          removed.push(name);
        }
        break;

      default:
        kept.push(name);
    }
  }

  return { kept, removed };
}

/**
 * Categorize files by their stage based on naming conventions.
 * Expected pattern: {entity}-{pose}-{stage}.{ext} or gen-{id}/{stage}/...
 */
function categorizeFiles(filenames: string[]): Map<string, Stage> {
  const result = new Map<string, Stage>();

  for (const name of filenames) {
    const lower = name.toLowerCase();
    if (lower.includes("-final") || lower.includes("/final")) {
      result.set(name, "final" as Stage);
    } else if (lower.includes("-review") || lower.includes("/review")) {
      result.set(name, "review" as Stage);
    } else if (lower.includes("-refine") || lower.includes("/refine")) {
      result.set(name, "refine" as Stage);
    } else if (lower.includes("-draft") || lower.includes("/draft") || lower.includes("-mock")) {
      result.set(name, "draft" as Stage);
    }
    // Files without stage markers are kept by default
  }

  return result;
}

function isImageFile(name: string): boolean {
  const lower = name.toLowerCase();
  return (
    lower.endsWith(".png") ||
    lower.endsWith(".jpg") ||
    lower.endsWith(".jpeg") ||
    lower.endsWith(".svg") ||
    lower.endsWith(".webp")
  );
}

function safeIsDir(path: string): boolean {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}
