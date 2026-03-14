import { describe, it, expect, vi, beforeEach } from "vitest";
import { evaluateDrift } from "../../src/stages/evaluate-drift.js";
import type {
  BrandEntity,
  SharedConfig,
  CompiledPrompt,
  Preset,
} from "../../src/types.js";

const TEST_ENTITY: BrandEntity = {
  id: "okyeame",
  name: "Okyeame",
  base_form: "Tall humanoid figure in ceremonial regalia",
  body_parts: {
    helm: { description: "Crested ceremonial helm" },
    torso: { description: "Layered plate armor" },
  },
  adinkra_ref: "nkyinkyim",
  not_this: ["exposed face or skin"],
};

const TEST_SHARED: SharedConfig = {
  adinkra_map: {
    nkyinkyim: { name: "Nkyinkyim", meaning: "Twisting" },
  },
};

const TEST_PROMPT: CompiledPrompt = {
  entity_id: "okyeame",
  main_prompt: "Okyeame prompt text",
  negative_prompt: "blurry",
  drift_checklist: [
    { name: "Helm present", status: "unknown" },
    { name: "Torso armor present", status: "unknown" },
    { name: "Adinkra symbol present", status: "unknown" },
  ],
  not_this_guards: ["exposed face or skin"],
  char_count: 100,
};

describe("evaluateDrift", () => {
  beforeEach(() => {
    // Clear any env vars
    delete process.env.ANTHROPIC_API_KEY;
    vi.clearAllMocks();
  });

  it("returns a drift report with quick evaluation", async () => {
    const preset: Preset = {
      name: "draft",
      model: "fal-ai/nano-banana-2",
      reference_sheet: false,
      max_iterations: 1,
      drift_evaluation: "quick",
      output_format: "jpg",
      requires_approval: false,
    };

    const report = await evaluateDrift({
      entity: TEST_ENTITY,
      shared: TEST_SHARED,
      prompt: TEST_PROMPT,
      imagePath: "/fake/image.png",
      preset,
    });

    expect(report).toBeDefined();
    expect(report.checks).toHaveLength(3);
    expect(report.checks[0].name).toBe("Helm present");
    expect(report.summary).toContain("visual inspection");
  });

  it("returns enhanced summary with quick_plus evaluation", async () => {
    const preset: Preset = {
      name: "review",
      model: "fal-ai/flux-pro",
      reference_sheet: false,
      max_iterations: 1,
      drift_evaluation: "quick_plus",
      output_format: "jpg",
      requires_approval: true,
    };

    const report = await evaluateDrift({
      entity: TEST_ENTITY,
      shared: TEST_SHARED,
      prompt: TEST_PROMPT,
      imagePath: "/fake/image.png",
      preset,
    });

    expect(report.summary).toContain("Entity profile");
    expect(report.summary).toContain("Okyeame");
    expect(report.summary).toContain("NOT_THIS guards");
  });

  it("throws for vision evaluation without API key", async () => {
    const preset: Preset = {
      name: "final",
      model: "fal-ai/flux-pro/kontext/max/multi",
      reference_sheet: true,
      max_iterations: 3,
      pass_threshold: 85,
      drift_evaluation: "vision",
      output_format: "png",
      requires_approval: true,
    };

    await expect(
      evaluateDrift({
        entity: TEST_ENTITY,
        shared: TEST_SHARED,
        prompt: TEST_PROMPT,
        imagePath: "/fake/image.png",
        preset,
      }),
    ).rejects.toThrow("ANTHROPIC_API_KEY");
  });

  it("returns all checklist items as unknown in quick mode", async () => {
    const preset: Preset = {
      name: "draft",
      model: "fal-ai/nano-banana-2",
      reference_sheet: false,
      max_iterations: 1,
      drift_evaluation: "quick",
      output_format: "jpg",
      requires_approval: false,
    };

    const report = await evaluateDrift({
      entity: TEST_ENTITY,
      shared: TEST_SHARED,
      prompt: TEST_PROMPT,
      imagePath: "/fake/image.png",
      preset,
    });

    for (const check of report.checks) {
      expect(check.status).toBe("unknown");
    }
  });
});
