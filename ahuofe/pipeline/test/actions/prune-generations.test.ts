import { describe, it, expect, afterEach } from "vitest";
import { mkdirSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { resolve, join } from "node:path";
import { planPrune } from "../../src/actions/prune-generations.js";
import type { Stage } from "../../src/types.js";

const TMP_DIR = resolve(__dirname, "../.tmp-prune");

function setupFiles(files: string[]): void {
  mkdirSync(TMP_DIR, { recursive: true });
  for (const f of files) {
    const filePath = join(TMP_DIR, f);
    writeFileSync(filePath, "mock content", "utf-8");
  }
}

describe("planPrune", () => {
  afterEach(() => {
    if (existsSync(TMP_DIR)) {
      rmSync(TMP_DIR, { recursive: true, force: true });
    }
  });

  it("keeps everything on draft stage (no pruning of drafts)", () => {
    setupFiles([
      "okyeame-idle-standing-draft.jpg",
      "okyeame-speaking-draft.jpg",
    ]);

    const result = planPrune({
      generationsDir: TMP_DIR,
      currentStage: "draft" as Stage,
    });

    expect(result.kept).toHaveLength(2);
    expect(result.removed).toHaveLength(0);
  });

  it("removes drafts on review stage", () => {
    setupFiles([
      "okyeame-idle-standing-draft.jpg",
      "okyeame-idle-standing-review.jpg",
    ]);

    const result = planPrune({
      generationsDir: TMP_DIR,
      currentStage: "review" as Stage,
    });

    expect(result.removed).toContain("okyeame-idle-standing-draft.jpg");
    expect(result.kept).toContain("okyeame-idle-standing-review.jpg");
  });

  it("removes everything except finals on final stage", () => {
    setupFiles([
      "okyeame-idle-standing-draft.jpg",
      "okyeame-idle-standing-review.jpg",
      "okyeame-idle-standing-final.png",
    ]);

    const result = planPrune({
      generationsDir: TMP_DIR,
      currentStage: "final" as Stage,
    });

    expect(result.kept).toContain("okyeame-idle-standing-final.png");
    expect(result.removed).toContain("okyeame-idle-standing-draft.jpg");
    expect(result.removed).toContain("okyeame-idle-standing-review.jpg");
  });

  it("preserves explicitly kept IDs", () => {
    setupFiles([
      "okyeame-idle-standing-draft.jpg",
      "okyeame-idle-standing-review.jpg",
    ]);

    const result = planPrune({
      generationsDir: TMP_DIR,
      currentStage: "final" as Stage,
      keepIds: ["okyeame-idle-standing-draft.jpg"],
    });

    expect(result.kept).toContain("okyeame-idle-standing-draft.jpg");
  });

  it("handles missing generations directory", () => {
    const result = planPrune({
      generationsDir: "/nonexistent/dir",
      currentStage: "draft" as Stage,
    });

    expect(result.kept).toHaveLength(0);
    expect(result.removed).toHaveLength(0);
  });

  it("categorizes files without stage marker as kept", () => {
    setupFiles([
      "some-random-file.png",
      "okyeame-idle-standing-draft.jpg",
    ]);

    const result = planPrune({
      generationsDir: TMP_DIR,
      currentStage: "review" as Stage,
    });

    expect(result.kept).toContain("some-random-file.png");
    expect(result.removed).toContain("okyeame-idle-standing-draft.jpg");
  });
});
