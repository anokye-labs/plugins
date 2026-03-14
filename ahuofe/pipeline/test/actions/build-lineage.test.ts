import { describe, it, expect, afterEach } from "vitest";
import { mkdirSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { resolve, join } from "node:path";
import {
  loadLineage,
  addLineageEntry,
  findLatestGeneration,
  buildLineageFromDir,
  getGenerationChain,
} from "../../src/actions/build-lineage.js";
import type { LineageEntry, Stage } from "../../src/types.js";

const TMP_DIR = resolve(__dirname, "../.tmp-lineage");

describe("loadLineage", () => {
  afterEach(() => {
    if (existsSync(TMP_DIR)) {
      rmSync(TMP_DIR, { recursive: true, force: true });
    }
  });

  it("returns empty lineage for nonexistent file", () => {
    const lineage = loadLineage("/nonexistent/lineage.json");
    expect(lineage.generations).toEqual([]);
  });

  it("loads existing lineage from JSON", () => {
    mkdirSync(TMP_DIR, { recursive: true });
    const lineagePath = join(TMP_DIR, "lineage.json");
    writeFileSync(
      lineagePath,
      JSON.stringify({
        generations: [
          {
            id: "gen-001",
            timestamp: "2026-03-13T10:00:00Z",
            parent: null,
            entity_id: "okyeame",
            stage: "draft",
            image_count: 1,
            model: "fal-ai/nano-banana-2",
          },
        ],
      }),
    );

    const lineage = loadLineage(lineagePath);
    expect(lineage.generations).toHaveLength(1);
    expect(lineage.generations[0].id).toBe("gen-001");
  });
});

describe("addLineageEntry", () => {
  it("appends a new entry to the lineage", () => {
    const lineage = { generations: [] };
    const entry: LineageEntry = {
      id: "gen-001",
      timestamp: "2026-03-13T10:00:00Z",
      parent: null,
      entity_id: "okyeame",
      stage: "draft" as Stage,
      image_count: 1,
      model: "fal-ai/nano-banana-2",
    };

    const updated = addLineageEntry(lineage, entry);
    expect(updated.generations).toHaveLength(1);
    expect(updated.generations[0].id).toBe("gen-001");
  });

  it("does not mutate the original lineage", () => {
    const lineage = { generations: [] };
    const entry: LineageEntry = {
      id: "gen-001",
      timestamp: "2026-03-13T10:00:00Z",
      parent: null,
      entity_id: "okyeame",
      stage: "draft" as Stage,
      image_count: 1,
      model: "fal-ai/nano-banana-2",
    };

    addLineageEntry(lineage, entry);
    expect(lineage.generations).toHaveLength(0);
  });
});

describe("findLatestGeneration", () => {
  const lineage = {
    generations: [
      {
        id: "gen-001",
        timestamp: "2026-03-13T10:00:00Z",
        parent: null,
        entity_id: "okyeame",
        stage: "draft" as Stage,
        image_count: 1,
        model: "fal-ai/nano-banana-2",
      },
      {
        id: "gen-002",
        timestamp: "2026-03-13T11:00:00Z",
        parent: "gen-001",
        entity_id: "okyeame",
        stage: "review" as Stage,
        image_count: 1,
        model: "fal-ai/flux-pro",
      },
      {
        id: "gen-003",
        timestamp: "2026-03-13T12:00:00Z",
        parent: null,
        entity_id: "ohemaa",
        stage: "draft" as Stage,
        image_count: 1,
        model: "fal-ai/nano-banana-2",
      },
    ],
  };

  it("finds the latest generation for an entity", () => {
    const latest = findLatestGeneration(lineage, "okyeame");
    expect(latest?.id).toBe("gen-002");
  });

  it("filters by stage when specified", () => {
    const latest = findLatestGeneration(lineage, "okyeame", "draft" as Stage);
    expect(latest?.id).toBe("gen-001");
  });

  it("returns undefined for unknown entity", () => {
    const latest = findLatestGeneration(lineage, "unknown");
    expect(latest).toBeUndefined();
  });
});

describe("buildLineageFromDir", () => {
  afterEach(() => {
    if (existsSync(TMP_DIR)) {
      rmSync(TMP_DIR, { recursive: true, force: true });
    }
  });

  it("builds lineage from manifest files in gen directories", () => {
    mkdirSync(join(TMP_DIR, "gen-001"), { recursive: true });
    mkdirSync(join(TMP_DIR, "gen-002"), { recursive: true });

    writeFileSync(
      join(TMP_DIR, "gen-001", "manifest.json"),
      JSON.stringify({
        id: "gen-001",
        timestamp: "2026-03-13T10:00:00Z",
        parent: null,
        entity_id: "okyeame",
        stage: "draft",
        image_count: 1,
        model: "fal-ai/nano-banana-2",
      }),
    );

    writeFileSync(
      join(TMP_DIR, "gen-002", "manifest.json"),
      JSON.stringify({
        id: "gen-002",
        timestamp: "2026-03-13T11:00:00Z",
        parent: "gen-001",
        entity_id: "okyeame",
        stage: "review",
        image_count: 1,
        model: "fal-ai/flux-pro",
      }),
    );

    const lineage = buildLineageFromDir(TMP_DIR);
    expect(lineage.generations).toHaveLength(2);
    expect(lineage.generations[0].id).toBe("gen-001");
    expect(lineage.generations[1].parent).toBe("gen-001");
  });

  it("returns empty lineage for nonexistent directory", () => {
    const lineage = buildLineageFromDir("/nonexistent/dir");
    expect(lineage.generations).toEqual([]);
  });
});

describe("getGenerationChain", () => {
  it("returns ancestor chain for a generation", () => {
    const lineage = {
      generations: [
        {
          id: "gen-001",
          timestamp: "t1",
          parent: null,
          entity_id: "okyeame",
          stage: "draft" as Stage,
          image_count: 1,
          model: "m1",
        },
        {
          id: "gen-002",
          timestamp: "t2",
          parent: "gen-001",
          entity_id: "okyeame",
          stage: "review" as Stage,
          image_count: 1,
          model: "m2",
        },
        {
          id: "gen-003",
          timestamp: "t3",
          parent: "gen-002",
          entity_id: "okyeame",
          stage: "final" as Stage,
          image_count: 1,
          model: "m3",
        },
      ],
    };

    const chain = getGenerationChain(lineage, "gen-003");
    expect(chain).toHaveLength(3);
    expect(chain[0].id).toBe("gen-001");
    expect(chain[1].id).toBe("gen-002");
    expect(chain[2].id).toBe("gen-003");
  });

  it("returns empty chain for unknown ID", () => {
    const lineage = { generations: [] };
    const chain = getGenerationChain(lineage, "gen-999");
    expect(chain).toEqual([]);
  });
});
