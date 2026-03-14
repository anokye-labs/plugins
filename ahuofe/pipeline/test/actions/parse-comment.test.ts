import { describe, it, expect } from "vitest";
import {
  parseComment,
  impliedStage,
  requiresEntity,
} from "../../src/actions/parse-comment.js";

describe("parseComment", () => {
  it("parses a generate command with entity", () => {
    const result = parseComment("@ahuofe generate okyeame");
    expect(result.command).toBe("generate");
    expect(result.entity).toBe("okyeame");
  });

  it("parses a review command", () => {
    const result = parseComment("@ahuofe review okyeame");
    expect(result.command).toBe("review");
    expect(result.entity).toBe("okyeame");
  });

  it("parses a finalize command", () => {
    const result = parseComment("@ahuofe finalize okyeame");
    expect(result.command).toBe("finalize");
    expect(result.entity).toBe("okyeame");
  });

  it("parses a reroll command with --seed flag", () => {
    const result = parseComment("@ahuofe reroll okyeame --seed 42");
    expect(result.command).toBe("reroll");
    expect(result.entity).toBe("okyeame");
    expect(result.options.seed).toBe("42");
  });

  it("parses an approve command", () => {
    const result = parseComment("@ahuofe approve");
    expect(result.command).toBe("approve");
  });

  it("parses a generate command with --pose flag", () => {
    const result = parseComment(
      "@ahuofe generate okyeame --pose idle-standing",
    );
    expect(result.command).toBe("generate");
    expect(result.entity).toBe("okyeame");
    expect(result.pose).toBe("idle-standing");
  });

  it("parses a generate command with --stage flag", () => {
    const result = parseComment(
      "@ahuofe generate okyeame --stage review",
    );
    expect(result.command).toBe("generate");
    expect(result.stage).toBe("review");
  });

  it("parses evaluate command", () => {
    const result = parseComment("@ahuofe evaluate okyeame");
    expect(result.command).toBe("evaluate");
    expect(result.entity).toBe("okyeame");
  });

  it("parses status command (no entity required)", () => {
    const result = parseComment("@ahuofe status");
    expect(result.command).toBe("status");
  });

  it("parses cost command", () => {
    const result = parseComment("@ahuofe cost");
    expect(result.command).toBe("cost");
  });

  it("returns none for unrecognized command", () => {
    const result = parseComment("@ahuofe dance");
    expect(result.command).toBe("none");
  });

  it("returns none for text without command prefix", () => {
    const result = parseComment("just a regular comment");
    expect(result.command).toBe("none");
  });

  it("is case-insensitive for commands", () => {
    const result = parseComment("@ahuofe GENERATE okyeame");
    expect(result.command).toBe("generate");
  });

  it("handles custom command prefix", () => {
    const result = parseComment("@custom-bot generate okyeame", "@custom-bot");
    expect(result.command).toBe("generate");
    expect(result.entity).toBe("okyeame");
  });

  it("preserves the raw comment body", () => {
    const body = "@ahuofe generate okyeame --pose idle-standing";
    const result = parseComment(body);
    expect(result.raw).toBe(body);
  });

  it("parses quoted string arguments", () => {
    const result = parseComment(
      '@ahuofe generate okyeame --note "kente should be heavier"',
    );
    expect(result.options.note).toBe("kente should be heavier");
  });

  it("parses batch command with entities flag", () => {
    const result = parseComment(
      "@ahuofe batch --entities okyeame,ohemaa --stage draft",
    );
    expect(result.command).toBe("batch");
    expect(result.options.entities).toBe("okyeame,ohemaa");
    expect(result.stage).toBe("draft");
  });
});

describe("impliedStage", () => {
  it("returns draft for generate/regenerate/reroll", () => {
    expect(impliedStage("generate")).toBe("draft");
    expect(impliedStage("regenerate")).toBe("draft");
    expect(impliedStage("reroll")).toBe("draft");
  });

  it("returns review for review command", () => {
    expect(impliedStage("review")).toBe("review");
  });

  it("returns final for finalize command", () => {
    expect(impliedStage("finalize")).toBe("final");
  });

  it("returns undefined for non-generation commands", () => {
    expect(impliedStage("approve")).toBeUndefined();
    expect(impliedStage("status")).toBeUndefined();
    expect(impliedStage("cost")).toBeUndefined();
  });
});

describe("requiresEntity", () => {
  it("returns true for commands that need an entity", () => {
    expect(requiresEntity("generate")).toBe(true);
    expect(requiresEntity("review")).toBe(true);
    expect(requiresEntity("finalize")).toBe(true);
    expect(requiresEntity("evaluate")).toBe(true);
    expect(requiresEntity("reroll")).toBe(true);
  });

  it("returns false for commands that do not need an entity", () => {
    expect(requiresEntity("approve")).toBe(false);
    expect(requiresEntity("status")).toBe(false);
    expect(requiresEntity("cost")).toBe(false);
    expect(requiresEntity("none")).toBe(false);
  });
});
