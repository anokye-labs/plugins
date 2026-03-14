/**
 * Build lineage.json tracking parent-child generation relationships across commits.
 */
import { readFileSync, writeFileSync, existsSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import type { LineageEntry, Stage } from "../types.js";

export interface Lineage {
  generations: LineageEntry[];
}

/**
 * Load existing lineage from a JSON file.
 */
export function loadLineage(lineagePath: string): Lineage {
  const absPath = resolve(lineagePath);
  if (!existsSync(absPath)) {
    return { generations: [] };
  }

  try {
    const raw = readFileSync(absPath, "utf-8");
    return JSON.parse(raw) as Lineage;
  } catch {
    return { generations: [] };
  }
}

/**
 * Save lineage to a JSON file.
 */
export function saveLineage(lineagePath: string, lineage: Lineage): void {
  const absPath = resolve(lineagePath);
  writeFileSync(absPath, JSON.stringify(lineage, null, 2), "utf-8");
}

/**
 * Add a new generation entry to the lineage.
 */
export function addLineageEntry(
  lineage: Lineage,
  entry: LineageEntry,
): Lineage {
  return {
    generations: [...lineage.generations, entry],
  };
}

/**
 * Find the latest generation for a given entity and optional stage.
 */
export function findLatestGeneration(
  lineage: Lineage,
  entityId: string,
  stage?: Stage,
): LineageEntry | undefined {
  const filtered = lineage.generations.filter(
    (g) =>
      g.entity_id === entityId && (stage === undefined || g.stage === stage),
  );

  if (filtered.length === 0) return undefined;
  return filtered[filtered.length - 1];
}

/**
 * Build a lineage graph from a generations directory.
 * Scans for manifest.json files in generation directories.
 */
export function buildLineageFromDir(generationsDir: string): Lineage {
  const absDir = resolve(generationsDir);
  const lineage: Lineage = { generations: [] };

  if (!existsSync(absDir)) {
    return lineage;
  }

  const entries = readdirSync(absDir, { withFileTypes: true })
    .filter((e) => e.isDirectory() && e.name.startsWith("gen-"))
    .sort((a, b) => a.name.localeCompare(b.name));

  for (const entry of entries) {
    const manifestPath = join(absDir, entry.name, "manifest.json");
    if (!existsSync(manifestPath)) continue;

    try {
      const raw = readFileSync(manifestPath, "utf-8");
      const manifest = JSON.parse(raw) as Record<string, unknown>;

      const genEntry: LineageEntry = {
        id: (manifest.id as string) ?? entry.name,
        timestamp: (manifest.timestamp as string) ?? new Date().toISOString(),
        parent: (manifest.parent as string) ?? null,
        entity_id: (manifest.entity_id as string) ?? "unknown",
        pose_id: manifest.pose_id as string | undefined,
        stage: (manifest.stage as Stage) ?? ("draft" as Stage),
        image_count: (manifest.image_count as number) ?? 1,
        model: (manifest.model as string) ?? "unknown",
        drift_score: manifest.drift_score as number | undefined,
      };

      lineage.generations.push(genEntry);
    } catch {
      // Skip malformed manifests
    }
  }

  return lineage;
}

/**
 * Get the generation chain (ancestors) for a given generation ID.
 */
export function getGenerationChain(
  lineage: Lineage,
  generationId: string,
): LineageEntry[] {
  const chain: LineageEntry[] = [];
  const byId = new Map(lineage.generations.map((g) => [g.id, g]));

  let current = byId.get(generationId);
  while (current) {
    chain.unshift(current);
    current = current.parent ? byId.get(current.parent) : undefined;
  }

  return chain;
}
