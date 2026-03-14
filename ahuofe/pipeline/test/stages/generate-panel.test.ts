import { describe, it, expect, vi, beforeEach } from "vitest";
import type { CompiledPrompt, PipelineConfig, Stage } from "../../src/types.js";

vi.mock("../../src/fal/client.js", () => ({
  generateEphemeral: vi.fn(),
}));

import { generatePanel } from "../../src/stages/generate-panel.js";
import { generateEphemeral } from "../../src/fal/client.js";

const mockGenerateEphemeral = vi.mocked(generateEphemeral);

const TEST_PROMPT: CompiledPrompt = {
  entity_id: "okyeame",
  pose_id: "idle-standing",
  main_prompt: "Okyeame, tall humanoid figure in ceremonial regalia",
  negative_prompt: "blurry, low quality",
  drift_checklist: [
    { name: "Base form present", status: "unknown" },
  ],
  not_this_guards: ["exposed face"],
  char_count: 100,
};

const TEST_CONFIG = {
  fal: {
    retention: {
      cdn_expiration_seconds: 3600,
      store_payloads: false,
      delete_after_download: true,
    },
    models: {
      draft: "fal-ai/nano-banana-2",
      review: "fal-ai/flux-pro",
      final: "fal-ai/flux-pro/kontext/max/multi",
      reference: "fal-ai/flux-pro/kontext",
      evaluator: "claude-sonnet-4-20250514",
    },
  },
} as PipelineConfig;

describe("generatePanel", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("calls fal client with compiled prompt and correct model", async () => {
    mockGenerateEphemeral.mockResolvedValue({
      images: [
        {
          url: "https://fal.media/files/mock/panel.png",
          width: 1280,
          height: 720,
        },
      ],
      seed: 42,
    });

    const result = await generatePanel({
      prompt: TEST_PROMPT,
      config: TEST_CONFIG,
      stage: "draft" as Stage,
      outputDir: "/output",
    });

    expect(mockGenerateEphemeral).toHaveBeenCalledOnce();
    expect(mockGenerateEphemeral).toHaveBeenCalledWith(
      "fal-ai/nano-banana-2",
      expect.objectContaining({
        prompt: TEST_PROMPT.main_prompt,
        negative_prompt: TEST_PROMPT.negative_prompt,
        num_images: 1,
      }),
      TEST_CONFIG.fal,
    );

    expect(result.entity_id).toBe("okyeame");
    expect(result.pose_id).toBe("idle-standing");
    expect(result.stage).toBe("draft");
    expect(result.seed).toBe(42);
    expect(result.width).toBe(1280);
  });

  it("uses the correct model for each stage", async () => {
    mockGenerateEphemeral.mockResolvedValue({
      images: [{ url: "https://fal.media/files/mock/p.png", width: 1280, height: 720 }],
      seed: 1,
    });

    await generatePanel({
      prompt: TEST_PROMPT,
      config: TEST_CONFIG,
      stage: "review" as Stage,
      outputDir: "/output",
    });

    expect(mockGenerateEphemeral).toHaveBeenCalledWith(
      "fal-ai/flux-pro",
      expect.any(Object),
      expect.any(Object),
    );
  });

  it("passes seed when provided", async () => {
    mockGenerateEphemeral.mockResolvedValue({
      images: [{ url: "https://fal.media/files/mock/p.png", width: 1280, height: 720 }],
      seed: 42,
    });

    await generatePanel({
      prompt: TEST_PROMPT,
      config: TEST_CONFIG,
      stage: "draft" as Stage,
      outputDir: "/output",
      seed: 42,
    });

    const input = mockGenerateEphemeral.mock.calls[0][1] as Record<string, unknown>;
    expect(input.seed).toBe(42);
  });

  it("throws when no images are returned", async () => {
    mockGenerateEphemeral.mockResolvedValue({ images: [] });

    await expect(
      generatePanel({
        prompt: TEST_PROMPT,
        config: TEST_CONFIG,
        stage: "draft" as Stage,
        outputDir: "/output",
      }),
    ).rejects.toThrow("Generation failed for okyeame: no images returned");
  });

  it("throws for unconfigured stage model", async () => {
    const badConfig = {
      fal: {
        retention: TEST_CONFIG.fal.retention,
        models: {} as Record<string, string>,
      },
    } as PipelineConfig;

    await expect(
      generatePanel({
        prompt: TEST_PROMPT,
        config: badConfig,
        stage: "draft" as Stage,
        outputDir: "/output",
      }),
    ).rejects.toThrow("No model configured for stage");
  });
});
