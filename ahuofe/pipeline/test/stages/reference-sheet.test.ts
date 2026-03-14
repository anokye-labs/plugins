import { describe, it, expect, vi, beforeEach } from "vitest";
import type { BrandEntity, SharedConfig, PipelineConfig } from "../../src/types.js";

// Mock the fal client before importing the module under test
vi.mock("../../src/fal/client.js", () => ({
  generateEphemeral: vi.fn(),
}));

import { generateReferenceSheet } from "../../src/stages/reference-sheet.js";
import { generateEphemeral } from "../../src/fal/client.js";

const mockGenerateEphemeral = vi.mocked(generateEphemeral);

const TEST_ENTITY: BrandEntity = {
  id: "okyeame",
  name: "Okyeame",
  base_form: "Tall humanoid figure in ceremonial regalia",
  body_parts: {
    helm: { description: "Crested ceremonial helm" },
    torso: { description: "Layered plate armor" },
  },
  proportions: { height: "7 heads tall" },
};

const TEST_SHARED: SharedConfig = {
  environment: {
    lighting: "Golden hour side-lighting",
  },
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

describe("generateReferenceSheet", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("calls fal client with the reference model", async () => {
    mockGenerateEphemeral.mockResolvedValue({
      images: [
        {
          url: "https://fal.media/files/mock/ref-sheet.png",
          width: 1280,
          height: 720,
        },
      ],
      seed: 99,
    });

    const result = await generateReferenceSheet(
      TEST_ENTITY,
      TEST_SHARED,
      TEST_CONFIG,
      "/output",
    );

    expect(mockGenerateEphemeral).toHaveBeenCalledOnce();
    expect(mockGenerateEphemeral).toHaveBeenCalledWith(
      "fal-ai/flux-pro/kontext",
      expect.objectContaining({
        prompt: expect.stringContaining("Okyeame"),
        num_images: 1,
      }),
      TEST_CONFIG.fal,
    );

    expect(result.entity_id).toBe("okyeame");
    expect(result.image.url).toContain("ref-sheet.png");
    expect(result.seed).toBe(99);
  });

  it("throws when no images are returned", async () => {
    mockGenerateEphemeral.mockResolvedValue({
      images: [],
    });

    await expect(
      generateReferenceSheet(TEST_ENTITY, TEST_SHARED, TEST_CONFIG, "/output"),
    ).rejects.toThrow("Reference sheet generation failed");
  });

  it("includes body part descriptions in the reference prompt", async () => {
    mockGenerateEphemeral.mockResolvedValue({
      images: [{ url: "https://fal.media/files/mock/ref.png", width: 1280, height: 720 }],
      seed: 1,
    });

    await generateReferenceSheet(TEST_ENTITY, TEST_SHARED, TEST_CONFIG, "/output");

    const callArgs = mockGenerateEphemeral.mock.calls[0];
    const input = callArgs[1] as Record<string, unknown>;
    const prompt = input.prompt as string;

    expect(prompt).toContain("reference sheet");
    expect(prompt).toContain("Crested ceremonial helm");
    expect(prompt).toContain("Layered plate armor");
  });
});
