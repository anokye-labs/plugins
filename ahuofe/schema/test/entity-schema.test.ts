import { describe, it, expect, beforeAll } from "vitest";
import { createAjv, loadSchema, loadFixture } from "./helpers";
import type { ValidateFunction } from "ajv";

describe("entity.schema.json", () => {
  let validate: ValidateFunction;

  beforeAll(() => {
    const ajv = createAjv();
    const schema = loadSchema("entity.schema.json");
    validate = ajv.compile(schema);
  });

  it("accepts a valid entity fixture", () => {
    const data = loadFixture("valid-entity.yaml");
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects entity missing base_form", () => {
    const data = loadFixture("invalid-entity-no-base-form.yaml");
    const valid = validate(data);
    expect(valid).toBe(false);
    expect(validate.errors).toBeDefined();
    const errorKeywords = validate.errors!.map((e) => e.keyword);
    const errorPaths = validate.errors!.map(
      (e) => e.instancePath || e.params?.missingProperty
    );
    expect(errorKeywords).toContain("required");
    expect(errorPaths).toContain("base_form");
  });

  it("rejects entity missing proportions", () => {
    const data = {
      name: "Test Entity",
      base_form: {
        type: "humanoid",
        description: "A test entity",
      },
      // missing proportions
    };
    const valid = validate(data);
    expect(valid).toBe(false);
    const missingProps = validate.errors!
      .filter((e) => e.keyword === "required")
      .map((e) => e.params?.missingProperty);
    expect(missingProps).toContain("proportions");
  });

  it("rejects invalid adinkra reference format", () => {
    const data = {
      name: "Test Entity",
      base_form: { type: "humanoid", description: "A test" },
      proportions: { head_ratio: 0.12 },
      adinkra: "sankofa", // missing adinkra: prefix
    };
    const valid = validate(data);
    expect(valid).toBe(false);
    const patternErrors = validate.errors!.filter(
      (e) => e.keyword === "pattern"
    );
    expect(patternErrors.length).toBeGreaterThan(0);
  });

  it("accepts NOT_THIS guard syntax in descriptive fields", () => {
    const data = {
      name: "Guard Entity",
      base_form: {
        type: "humanoid",
        description: "A normal description",
        silhouette: "NOT_THIS: slouching or hunched posture",
      },
      proportions: { head_ratio: 0.5 },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("validates body_parts nesting correctly", () => {
    const data = {
      name: "Body Parts Entity",
      base_form: { type: "humanoid", description: "Test" },
      proportions: { head_ratio: 0.12 },
      body_parts: {
        head: {
          description: "Noble head",
          material: "gold",
          color: "#D4AF37",
          adinkra: "adinkra:dwennimmen",
          details: ["Crown with prongs", "Scarification marks"],
          not_this: ["NOT_THIS: western crown"],
        },
        torso: {
          description: "Broad torso draped in kente",
          material: "kente",
        },
      },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects body_parts with invalid adinkra ref", () => {
    const data = {
      name: "Bad Body Part",
      base_form: { type: "humanoid", description: "Test" },
      proportions: { head_ratio: 0.12 },
      body_parts: {
        head: {
          description: "head",
          adinkra: "bad-ref", // not adinkra:xxx format
        },
      },
    };
    const valid = validate(data);
    expect(valid).toBe(false);
    expect(validate.errors).toBeDefined();
  });

  it("allows extra unknown properties for extensibility", () => {
    const data = {
      name: "Extended Entity",
      base_form: { type: "humanoid", description: "Test" },
      proportions: { head_ratio: 0.12 },
      custom_field: "some custom value",
      future_feature: { nested: true },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects base_form missing required type field", () => {
    const data = {
      name: "Missing Type",
      base_form: {
        description: "A description but no type",
      },
      proportions: { head_ratio: 0.12 },
    };
    const valid = validate(data);
    expect(valid).toBe(false);
    const requiredErrors = validate.errors!.filter(
      (e) => e.keyword === "required"
    );
    expect(requiredErrors.length).toBeGreaterThan(0);
  });

  it("rejects proportion values outside 0-1 range", () => {
    const data = {
      name: "Bad Proportions",
      base_form: { type: "humanoid", description: "Test" },
      proportions: { head_ratio: 1.5 },
    };
    const valid = validate(data);
    expect(valid).toBe(false);
    const maxErrors = validate.errors!.filter((e) => e.keyword === "maximum");
    expect(maxErrors.length).toBeGreaterThan(0);
  });

  it("rejects body_parts not_this entries without NOT_THIS: prefix", () => {
    const data = {
      name: "Bad Guard",
      base_form: { type: "humanoid", description: "Test" },
      proportions: { head_ratio: 0.12 },
      body_parts: {
        head: {
          description: "head",
          not_this: ["just a plain string without prefix"],
        },
      },
    };
    const valid = validate(data);
    expect(valid).toBe(false);
  });
});
