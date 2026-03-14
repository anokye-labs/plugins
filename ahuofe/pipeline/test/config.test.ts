import { describe, it, expect, afterEach } from "vitest";
import { writeFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { resolve, join } from "node:path";
import { loadConfig, resolveBrandPath } from "../src/config.js";

const TMP_DIR = resolve(__dirname, ".tmp-config");

describe("loadConfig", () => {
  afterEach(() => {
    if (existsSync(TMP_DIR)) {
      rmSync(TMP_DIR, { recursive: true, force: true });
    }
  });

  it("loads and parses a valid .ahuofe.yaml config", () => {
    mkdirSync(TMP_DIR, { recursive: true });
    const configPath = join(TMP_DIR, ".ahuofe.yaml");
    writeFileSync(
      configPath,
      `
plugin:
  repo: anokye-labs/plugins
  path: ahuofe
  ref: main

project:
  name: "Test Project"
  command_prefix: "@ahuofe"

brand_path: "./brand"

defaults:
  stage: draft
  max_iterations: 5
  pass_threshold: 90

fal:
  models:
    draft: fal-ai/test-model
`,
    );

    const config = loadConfig(configPath);

    expect(config.plugin.repo).toBe("anokye-labs/plugins");
    expect(config.project.name).toBe("Test Project");
    expect(config.brand_path).toBe("./brand");
    expect(config.defaults.max_iterations).toBe(5);
    expect(config.defaults.pass_threshold).toBe(90);
    expect(config.fal.models.draft).toBe("fal-ai/test-model");
  });

  it("applies defaults for missing fields", () => {
    mkdirSync(TMP_DIR, { recursive: true });
    const configPath = join(TMP_DIR, "minimal.yaml");
    writeFileSync(
      configPath,
      `
project:
  name: "Minimal"
  command_prefix: "@min"
`,
    );

    const config = loadConfig(configPath);

    // Defaults should be applied
    expect(config.defaults.stage).toBe("draft");
    expect(config.defaults.max_iterations).toBe(3);
    expect(config.defaults.pass_threshold).toBe(85);
    expect(config.approval.auto_approve_draft).toBe(true);
    expect(config.fal.retention.cdn_expiration_seconds).toBe(3600);
    expect(config.fal.retention.store_payloads).toBe(false);
    expect(config.fal.models.draft).toBe("fal-ai/nano-banana-2");
  });

  it("throws for missing config file", () => {
    expect(() => loadConfig("/nonexistent/.ahuofe.yaml")).toThrow(
      "Config file not found",
    );
  });

  it("throws for invalid YAML content", () => {
    mkdirSync(TMP_DIR, { recursive: true });
    const configPath = join(TMP_DIR, "invalid.yaml");
    writeFileSync(configPath, "just a plain string");

    expect(() => loadConfig(configPath)).toThrow("Invalid config file");
  });

  it("validates required fields from config", () => {
    mkdirSync(TMP_DIR, { recursive: true });
    const configPath = join(TMP_DIR, "valid.yaml");
    writeFileSync(
      configPath,
      `
project:
  name: Test
  command_prefix: "@test"
approval:
  require_human_approval: false
  approvers:
    - user1
    - user2
`,
    );

    const config = loadConfig(configPath);
    expect(config.approval.require_human_approval).toBe(false);
    expect(config.approval.approvers).toEqual(["user1", "user2"]);
  });
});

describe("resolveBrandPath", () => {
  it("resolves relative brand path against config directory", () => {
    const configPath = "/project/.ahuofe.yaml";
    const result = resolveBrandPath(configPath, "./brand");
    expect(result).toContain("brand");
  });

  it("returns absolute brand path as-is", () => {
    const configPath = "/project/.ahuofe.yaml";
    const result = resolveBrandPath(configPath, "/absolute/brand");
    expect(result).toBe("/absolute/brand");
  });
});
