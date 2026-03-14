import { describe, it, expect } from "vitest";
import {
  parseBrandDiff,
  formatAsActionsOutput,
} from "../../src/actions/diff-brand.js";

describe("parseBrandDiff", () => {
  it("detects changed entity files", () => {
    const diff = `brand/entities/physical/okyeame.yaml
brand/entities/virtual/ananse.yaml
brand/shared/colors.yaml
README.md`;

    const result = parseBrandDiff(diff, "brand");

    expect(result.affectedEntities).toContain("okyeame");
    expect(result.affectedEntities).toContain("ananse");
    expect(result.affectedEntities).toHaveLength(2);
  });

  it("detects shared config changes", () => {
    const diff = `brand/shared/colors.yaml
brand/shared/materials.yaml`;

    const result = parseBrandDiff(diff, "brand");
    expect(result.hasSharedChanges).toBe(true);
    expect(result.affectedEntities).toHaveLength(0);
  });

  it("ignores files outside brand path", () => {
    const diff = `README.md
src/index.ts
brand/entities/physical/okyeame.yaml`;

    const result = parseBrandDiff(diff, "brand");
    expect(result.changedFiles).toHaveLength(1);
    expect(result.affectedEntities).toEqual(["okyeame"]);
  });

  it("handles empty diff output", () => {
    const result = parseBrandDiff("", "brand");
    expect(result.changedFiles).toHaveLength(0);
    expect(result.affectedEntities).toHaveLength(0);
    expect(result.hasSharedChanges).toBe(false);
  });

  it("ignores preset files", () => {
    const diff = `brand/presets/draft.yaml
brand/presets/final.yaml
brand/entities/physical/okyeame.yaml`;

    const result = parseBrandDiff(diff, "brand");
    expect(result.affectedEntities).toEqual(["okyeame"]);
    expect(result.changedFiles).toHaveLength(3);
  });

  it("handles trailing slash in brand path", () => {
    const diff = `brand/entities/physical/okyeame.yaml`;
    const result = parseBrandDiff(diff, "brand/");
    expect(result.affectedEntities).toEqual(["okyeame"]);
  });

  it("handles nested entity directories", () => {
    const diff = `brand/entities/physical/okyeame.yaml
brand/entities/virtual/sankofa.yaml
brand/entities/collective/ahene-council.yaml`;

    const result = parseBrandDiff(diff, "brand");
    expect(result.affectedEntities).toContain("okyeame");
    expect(result.affectedEntities).toContain("sankofa");
    expect(result.affectedEntities).toContain("ahene-council");
    expect(result.affectedEntities).toHaveLength(3);
  });
});

describe("formatAsActionsOutput", () => {
  it("formats entities as JSON array", () => {
    const result = parseBrandDiff(
      "brand/entities/physical/okyeame.yaml",
      "brand",
    );
    const output = formatAsActionsOutput(result);
    expect(output).toContain('entities=["okyeame"]');
    expect(output).toContain("command=generate");
    expect(output).toContain("stage=draft");
    expect(output).toContain("requires_approval=false");
  });

  it("sets command to none when nothing changed", () => {
    const result = parseBrandDiff("README.md", "brand");
    const output = formatAsActionsOutput(result);
    expect(output).toContain("command=none");
  });

  it("sets command to generate when shared files changed", () => {
    const result = parseBrandDiff("brand/shared/colors.yaml", "brand");
    const output = formatAsActionsOutput(result);
    expect(output).toContain("command=generate");
    expect(output).toContain("has_shared_changes=true");
  });
});
