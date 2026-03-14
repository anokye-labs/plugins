import { describe, it, expect } from "vitest";
import { createAjv, loadSchema } from "./helpers";

const SCHEMA_FILES = [
  "entity.schema.json",
  "shared.schema.json",
  "preset.schema.json",
];

describe("meta-validation", () => {
  const ajv = createAjv();

  for (const file of SCHEMA_FILES) {
    describe(file, () => {
      const schema = loadSchema(file);

      it("has required $schema field", () => {
        expect(schema.$schema).toBe(
          "http://json-schema.org/draft-07/schema#"
        );
      });

      it("has type field", () => {
        expect(schema.type).toBe("object");
      });

      it("has properties field", () => {
        expect(schema.properties).toBeDefined();
        expect(typeof schema.properties).toBe("object");
      });

      it("has required field", () => {
        expect(schema.required).toBeDefined();
        expect(Array.isArray(schema.required)).toBe(true);
      });

      it("compiles without meta-schema errors", () => {
        const validate = ajv.compile(schema);
        expect(validate).toBeDefined();
        expect(typeof validate).toBe("function");
      });
    });
  }
});
