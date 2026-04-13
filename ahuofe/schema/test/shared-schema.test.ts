import { describe, it, expect, beforeAll } from "vitest";
import { createAjv, loadSchema, loadFixture } from "./helpers";
import type { ValidateFunction } from "ajv";

describe("shared.schema.json", () => {
  let validate: ValidateFunction;

  beforeAll(() => {
    const ajv = createAjv();
    const schema = loadSchema("shared.schema.json");
    validate = ajv.compile(schema);
  });

  it("accepts a valid shared config fixture", () => {
    const data = loadFixture("valid-shared.yaml");
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects bad color format (#GGG)", () => {
    const data = loadFixture("invalid-shared-bad-color.yaml");
    const valid = validate(data);
    expect(valid).toBe(false);
    expect(validate.errors).toBeDefined();
    // The error should relate to the color field
    const hasColorError = validate.errors!.some(
      (e) =>
        e.instancePath?.includes("color") ||
        e.instancePath?.includes("primary") ||
        e.schemaPath?.includes("color")
    );
    expect(hasColorError).toBe(true);
  });

  it("accepts valid hex color #D4AF37", () => {
    const data = {
      colors: {
        primary: "#D4AF37",
        secondary: "#8B4513",
        accent: "#FFFFFF",
      },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("accepts named colors", () => {
    const data = {
      colors: {
        primary: "gold",
        secondary: "brown",
        accent: "ivory",
      },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects unknown material types", () => {
    const data = {
      materials: {
        primary: {
          type: "plasteel", // not in material enum
          finish: "glossy",
        },
      },
    };
    const valid = validate(data);
    expect(valid).toBe(false);
    const enumErrors = validate.errors!.filter((e) => e.keyword === "enum");
    expect(enumErrors.length).toBeGreaterThan(0);
  });

  it("accepts valid material enum values", () => {
    const data = {
      materials: {
        cloth: {
          type: "kente",
          finish: "satin",
        },
        metal: {
          type: "gold",
          finish: "polished",
        },
      },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects proportion values outside 0-1 range", () => {
    const data = {
      proportions: {
        head_to_body: 1.5, // over max
      },
    };
    const valid = validate(data);
    expect(valid).toBe(false);
    const maxErrors = validate.errors!.filter((e) => e.keyword === "maximum");
    expect(maxErrors.length).toBeGreaterThan(0);
  });

  it("accepts proportion values within 0-1 range", () => {
    const data = {
      proportions: {
        head_to_body: 0.12,
        torso_to_total: 0.35,
      },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("accepts proportion as object with value and description", () => {
    const data = {
      proportions: {
        head_to_body: {
          value: 0.12,
          description: "Head is 12% of total height",
        },
      },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects negative proportion value", () => {
    const data = {
      proportions: {
        head_to_body: -0.5,
      },
    };
    const valid = validate(data);
    expect(valid).toBe(false);
  });

  it("accepts environment with string properties", () => {
    const data = {
      environment: {
        lighting: "warm golden ambient",
        background: "royal court",
        atmosphere: "ceremonial",
        time_of_day: "late afternoon",
        setting: "indoor hall",
      },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("accepts color objects in palette array", () => {
    const data = {
      colors: {
        palette: [
          { primary: "#D4AF37", secondary: "#8B4513" },
          "gold",
          "#C5A02E",
        ],
      },
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("accepts $ref for cross-file references", () => {
    const data = {
      $ref: "./colors.yaml",
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });
});
