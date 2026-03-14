import { readFileSync } from "fs";
import { join } from "path";
import Ajv from "ajv";
import addFormats from "ajv-formats";
import yaml from "js-yaml";

const SCHEMA_DIR = join(__dirname, "..");
const FIXTURES_DIR = join(__dirname, "fixtures");

export function createAjv(): Ajv {
  const ajv = new Ajv({ allErrors: true, strict: false });
  addFormats(ajv);
  return ajv;
}

export function loadSchema(filename: string): Record<string, unknown> {
  const content = readFileSync(join(SCHEMA_DIR, filename), "utf-8");
  return JSON.parse(content);
}

export function loadFixture(filename: string): unknown {
  const content = readFileSync(join(FIXTURES_DIR, filename), "utf-8");
  return yaml.load(content);
}
