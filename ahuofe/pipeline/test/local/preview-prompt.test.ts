import { describe, it, expect } from "vitest";
import { formatPrompt } from "../../src/local/preview-prompt.js";
import type { CompiledPrompt } from "../../src/types.js";

describe("formatPrompt", () => {
  const TEST_PROMPT: CompiledPrompt = {
    entity_id: "okyeame",
    pose_id: "idle-standing",
    main_prompt:
      "Okyeame, Tall humanoid figure in ceremonial regalia. Pose: Idle Standing",
    negative_prompt: "blurry, low quality, deformed",
    drift_checklist: [
      { name: "Helm present", status: "unknown" },
      { name: "Staff in right hand", status: "unknown" },
      { name: "Kente drape toga-style", status: "unknown" },
    ],
    not_this_guards: ["exposed face or skin", "modern clothing"],
    char_count: 120,
  };

  it("includes entity ID and pose in the header", () => {
    const output = formatPrompt(TEST_PROMPT);
    expect(output).toContain("okyeame");
    expect(output).toContain("idle-standing");
  });

  it("includes the main prompt text", () => {
    const output = formatPrompt(TEST_PROMPT);
    expect(output).toContain("MAIN PROMPT");
    expect(output).toContain("Okyeame, Tall humanoid figure");
  });

  it("includes the negative prompt", () => {
    const output = formatPrompt(TEST_PROMPT);
    expect(output).toContain("NEGATIVE PROMPT");
    expect(output).toContain("blurry, low quality, deformed");
  });

  it("formats drift checklist with checkbox markers", () => {
    const output = formatPrompt(TEST_PROMPT);
    expect(output).toContain("DRIFT CHECKLIST");
    expect(output).toContain("[ ] Helm present");
    expect(output).toContain("[ ] Staff in right hand");
    expect(output).toContain("[ ] Kente drape toga-style");
  });

  it("formats NOT_THIS guards", () => {
    const output = formatPrompt(TEST_PROMPT);
    expect(output).toContain("NOT_THIS GUARDS");
    expect(output).toContain("x  exposed face or skin");
    expect(output).toContain("x  modern clothing");
  });

  it("shows character count and token estimate", () => {
    const output = formatPrompt(TEST_PROMPT);
    expect(output).toContain("Character count: 120");
    expect(output).toContain("Estimated tokens: ~30");
  });

  it("omits NOT_THIS section when there are no guards", () => {
    const noGuards: CompiledPrompt = {
      ...TEST_PROMPT,
      not_this_guards: [],
    };

    const output = formatPrompt(noGuards);
    expect(output).not.toContain("NOT_THIS GUARDS");
  });
});
