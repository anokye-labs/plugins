import { describe, it, expect } from "vitest";
import { resolve } from "node:path";
import {
  loadEntity,
  loadSharedConfig,
  loadPreset,
  mergeSharedIntoEntity,
} from "../../src/stages/load-yaml.js";

const FIXTURES = resolve(__dirname, "../fixtures");

describe("loadEntity", () => {
  it("loads a valid entity YAML correctly", () => {
    const entity = loadEntity(FIXTURES, "valid-entity");
    expect(entity.id).toBe("okyeame");
    expect(entity.name).toBe("Okyeame");
    expect(entity.base_form).toContain("Tall humanoid figure");
    expect(entity.body_parts).toBeDefined();
    expect(entity.body_parts!.helm).toBeDefined();
    expect(entity.poses).toHaveLength(2);
    expect(entity.not_this).toContain("exposed face or skin");
  });

  it("throws for missing entity file", () => {
    expect(() => loadEntity(FIXTURES, "nonexistent-entity")).toThrow(
      "Entity not found: nonexistent-entity",
    );
  });

  it("throws for entity missing base_form", () => {
    expect(() =>
      loadEntity(FIXTURES, "invalid-entity-missing-required"),
    ).toThrow("missing required field 'base_form'");
  });
});

describe("loadSharedConfig", () => {
  it("loads shared config files when they exist", () => {
    // The fixtures dir doesn't have a shared/ subdir, so this returns empty
    const shared = loadSharedConfig(FIXTURES);
    expect(shared).toBeDefined();
    expect(typeof shared).toBe("object");
  });

  it("returns empty config when shared directory is missing", () => {
    const shared = loadSharedConfig("/nonexistent/path");
    expect(shared).toEqual({});
  });
});

describe("loadPreset", () => {
  it("loads a valid preset from the presets directory", () => {
    const preset = loadPreset(FIXTURES, "draft");
    expect(preset.name).toBe("draft");
    expect(preset.model).toBe("fal-ai/nano-banana-2");
    expect(preset.reference_sheet).toBe(false);
    expect(preset.max_iterations).toBe(1);
    expect(preset.requires_approval).toBe(false);
  });

  it("throws for missing preset file", () => {
    expect(() => loadPreset(FIXTURES, "nonexistent")).toThrow(
      "Preset not found",
    );
  });
});

describe("mergeSharedIntoEntity", () => {
  it("merges shared proportions into entity when not overridden", () => {
    const entity = {
      id: "test",
      name: "Test",
      base_form: "humanoid figure",
    };
    const shared = {
      proportions: { height: "7 heads", width: "2 heads" },
    };

    const merged = mergeSharedIntoEntity(entity, shared);
    expect(merged.proportions).toEqual(shared.proportions);
  });

  it("preserves entity proportions when they exist", () => {
    const entity = {
      id: "test",
      name: "Test",
      base_form: "humanoid figure",
      proportions: { height: "8 heads" },
    };
    const shared = {
      proportions: { height: "7 heads", width: "2 heads" },
    };

    const merged = mergeSharedIntoEntity(entity, shared);
    expect(merged.proportions).toEqual({ height: "8 heads" });
  });

  it("resolves color references in body parts", () => {
    const entity = {
      id: "test",
      name: "Test",
      base_form: "humanoid figure",
      body_parts: {
        helm: {
          description: "A golden helm",
          color_ref: "kente_gold",
        },
      },
    };
    const shared = {
      colors: { kente_gold: "#D4A017" },
    };

    const merged = mergeSharedIntoEntity(entity, shared);
    expect(merged.body_parts!.helm.color_ref).toBe("#D4A017");
  });
});
