import { describe, it, expect } from "vitest";
import { resolve } from "node:path";
import {
  validateEntityYaml,
  validateAllEntities,
} from "../../src/local/validate-yaml.js";

const FIXTURES = resolve(__dirname, "../fixtures");

describe("validateEntityYaml", () => {
  it("passes for a valid entity YAML", () => {
    const result = validateEntityYaml(
      resolve(FIXTURES, "valid-entity.yaml"),
    );
    expect(result.valid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  it("fails for entity missing base_form", () => {
    const result = validateEntityYaml(
      resolve(FIXTURES, "invalid-entity-missing-required.yaml"),
    );
    expect(result.valid).toBe(false);
    expect(result.errors.length).toBeGreaterThan(0);
    expect(result.errors[0].path).toContain("base_form");
    expect(result.errors[0].message).toContain("base_form");
  });

  it("fails for nonexistent file", () => {
    const result = validateEntityYaml(
      resolve(FIXTURES, "nonexistent.yaml"),
    );
    expect(result.valid).toBe(false);
    expect(result.errors[0].message).toContain("File not found");
  });

  it("returns errors with file path context", () => {
    const filePath = resolve(FIXTURES, "invalid-entity-missing-required.yaml");
    const result = validateEntityYaml(filePath);
    expect(result.file).toBe(filePath);
    for (const err of result.errors) {
      expect(err.file).toBe(filePath);
    }
  });
});

describe("validateAllEntities", () => {
  it("returns error when entities directory is missing", () => {
    const results = validateAllEntities("/nonexistent/brand");
    expect(results).toHaveLength(1);
    expect(results[0].valid).toBe(false);
    expect(results[0].errors[0].message).toContain(
      "Entities directory not found",
    );
  });
});
