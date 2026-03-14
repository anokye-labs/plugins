import { describe, it, expect, afterEach } from "vitest";
import { mkdirSync, rmSync, existsSync } from "node:fs";
import { resolve, join } from "node:path";
import { mockGenerate } from "../../src/local/mock-generate.js";
import type { BrandEntity, Stage } from "../../src/types.js";

const TEST_OUTPUT = resolve(__dirname, "../.tmp-mock-gen");

const TEST_ENTITY: BrandEntity = {
  id: "okyeame",
  name: "Okyeame",
  base_form: "Tall humanoid figure",
  body_parts: {
    helm: { description: "Crested helm" },
    torso: { description: "Plate armor" },
    staff: { description: "Linguist staff" },
  },
  poses: [
    { id: "idle-standing", name: "Idle Standing", description: "Standing pose" },
  ],
};

describe("mockGenerate", () => {
  afterEach(() => {
    if (existsSync(TEST_OUTPUT)) {
      rmSync(TEST_OUTPUT, { recursive: true, force: true });
    }
  });

  it("generates an SVG placeholder file", () => {
    const result = mockGenerate({
      entity: TEST_ENTITY,
      outputDir: TEST_OUTPUT,
    });

    expect(result.svgContent).toContain("<svg");
    expect(result.svgContent).toContain("Okyeame");
    expect(result.result.entity_id).toBe("okyeame");
    expect(result.result.model).toBe("mock-generator");
    expect(existsSync(result.result.image_path)).toBe(true);
  });

  it("respects custom dimensions", () => {
    const result = mockGenerate({
      entity: TEST_ENTITY,
      width: 800,
      height: 600,
      outputDir: TEST_OUTPUT,
    });

    expect(result.svgContent).toContain('width="800"');
    expect(result.svgContent).toContain('height="600"');
    expect(result.result.width).toBe(800);
    expect(result.result.height).toBe(600);
  });

  it("includes body part names in the SVG", () => {
    const result = mockGenerate({
      entity: TEST_ENTITY,
      outputDir: TEST_OUTPUT,
    });

    expect(result.svgContent).toContain("helm");
    expect(result.svgContent).toContain("torso");
    expect(result.svgContent).toContain("staff");
  });

  it("includes stage information in the SVG", () => {
    const result = mockGenerate({
      entity: TEST_ENTITY,
      stage: "review" as Stage,
      outputDir: TEST_OUTPUT,
    });

    expect(result.svgContent).toContain("REVIEW");
    expect(result.result.stage).toBe("review");
  });

  it("uses default dimensions of 1280x720", () => {
    const result = mockGenerate({
      entity: TEST_ENTITY,
      outputDir: TEST_OUTPUT,
    });

    expect(result.result.width).toBe(1280);
    expect(result.result.height).toBe(720);
  });

  it("creates the output directory if it does not exist", () => {
    const nestedOutput = join(TEST_OUTPUT, "nested", "dir");
    expect(existsSync(nestedOutput)).toBe(false);

    mockGenerate({
      entity: TEST_ENTITY,
      outputDir: nestedOutput,
    });

    expect(existsSync(nestedOutput)).toBe(true);
  });
});
