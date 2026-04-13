import { describe, it, expect, beforeAll } from "vitest";
import { createAjv, loadSchema, loadFixture } from "./helpers";
import type { ValidateFunction } from "ajv";

describe("preset.schema.json", () => {
  let validate: ValidateFunction;

  beforeAll(() => {
    const ajv = createAjv();
    const schema = loadSchema("preset.schema.json");
    validate = ajv.compile(schema);
  });

  it("accepts valid draft preset", () => {
    const data = loadFixture("valid-preset-draft.yaml");
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("accepts valid review preset", () => {
    const data = loadFixture("valid-preset-review.yaml");
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("accepts valid final preset", () => {
    const data = loadFixture("valid-preset-final.yaml");
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects unknown stage value 'production'", () => {
    const data = loadFixture("invalid-preset-unknown-stage.yaml");
    const valid = validate(data);
    expect(valid).toBe(false);
    expect(validate.errors).toBeDefined();
    const enumErrors = validate.errors!.filter((e) => e.keyword === "enum");
    expect(enumErrors.length).toBeGreaterThan(0);
    const stageError = enumErrors.find(
      (e) => e.instancePath === "/stage"
    );
    expect(stageError).toBeDefined();
  });

  it("rejects preset missing model field", () => {
    const data = {
      name: "no-model",
      stage: "draft",
      aspect_ratio: "16:9",
    };
    const valid = validate(data);
    expect(valid).toBe(false);
    const missingProps = validate.errors!
      .filter((e) => e.keyword === "required")
      .map((e) => e.params?.missingProperty);
    expect(missingProps).toContain("model");
  });

  it("rejects invalid aspect_ratio format", () => {
    const data = {
      name: "bad-ratio",
      model: "fal-ai/flux-pro",
      aspect_ratio: "wide", // not a ratio format
    };
    const valid = validate(data);
    expect(valid).toBe(false);
    const patternErrors = validate.errors!.filter(
      (e) => e.keyword === "pattern"
    );
    expect(patternErrors.length).toBeGreaterThan(0);
  });

  it("accepts valid aspect_ratio formats", () => {
    const ratios = ["16:9", "1:1", "4:3", "9:16", "21:9"];
    for (const ratio of ratios) {
      const data = {
        name: "ratio-test",
        model: "fal-ai/flux-pro",
        aspect_ratio: ratio,
      };
      const valid = validate(data);
      expect(validate.errors).toBeNull();
      expect(valid).toBe(true);
    }
  });

  it("rejects num_inference_steps outside bounds", () => {
    const tooLow = {
      name: "steps-low",
      model: "fal-ai/flux-pro",
      num_inference_steps: 0,
    };
    expect(validate(tooLow)).toBe(false);

    const tooHigh = {
      name: "steps-high",
      model: "fal-ai/flux-pro",
      num_inference_steps: 300,
    };
    expect(validate(tooHigh)).toBe(false);
  });

  it("accepts num_inference_steps within bounds", () => {
    const data = {
      name: "steps-ok",
      model: "fal-ai/flux-pro",
      num_inference_steps: 50,
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects guidance_scale outside bounds", () => {
    const tooHigh = {
      name: "guidance-high",
      model: "fal-ai/flux-pro",
      guidance_scale: 50,
    };
    expect(validate(tooHigh)).toBe(false);

    const negative = {
      name: "guidance-neg",
      model: "fal-ai/flux-pro",
      guidance_scale: -1,
    };
    expect(validate(negative)).toBe(false);
  });

  it("accepts guidance_scale within bounds", () => {
    const data = {
      name: "guidance-ok",
      model: "fal-ai/flux-pro",
      guidance_scale: 7.5,
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects max_iterations less than 1", () => {
    const data = {
      name: "iter-zero",
      model: "fal-ai/flux-pro",
      max_iterations: 0,
    };
    expect(validate(data)).toBe(false);
  });

  it("accepts valid seed values", () => {
    const data = {
      name: "seeded",
      model: "fal-ai/flux-pro",
      seed: 42,
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects negative seed", () => {
    const data = {
      name: "neg-seed",
      model: "fal-ai/flux-pro",
      seed: -1,
    };
    expect(validate(data)).toBe(false);
  });

  it("accepts pass_threshold in 0-100 range", () => {
    const data = {
      name: "threshold-ok",
      model: "fal-ai/flux-pro",
      pass_threshold: 85,
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects pass_threshold over 100", () => {
    const data = {
      name: "threshold-over",
      model: "fal-ai/flux-pro",
      pass_threshold: 150,
    };
    expect(validate(data)).toBe(false);
  });

  it("accepts optional negative_prompt and style_preset", () => {
    const data = {
      name: "with-optionals",
      model: "fal-ai/flux-pro",
      negative_prompt: "low quality, blurry",
      style_preset: "afro-futurism",
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("allows additional properties for extensibility", () => {
    const data = {
      name: "extended",
      model: "fal-ai/flux-pro",
      custom_param: "some-value",
      experimental: true,
    };
    const valid = validate(data);
    expect(validate.errors).toBeNull();
    expect(valid).toBe(true);
  });

  it("rejects aspect_ratio 0:9", () => {
    const data = {
      name: "zero-ratio",
      model: "fal-ai/flux-pro",
      aspect_ratio: "0:9",
    };
    expect(validate(data)).toBe(false);
  });
});
