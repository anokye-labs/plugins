import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// Mock the fal.ai client SDK
vi.mock("@fal-ai/client", () => ({
  fal: {
    config: vi.fn(),
    subscribe: vi.fn(),
  },
}));

// Mock cleanup
vi.mock("../../src/fal/cleanup.js", () => ({
  deleteFromCdn: vi.fn().mockResolvedValue(undefined),
}));

import { fal } from "@fal-ai/client";
import { generateEphemeral, configureFalClient } from "../../src/fal/client.js";
import { deleteFromCdn } from "../../src/fal/cleanup.js";
import type { FalConfig } from "../../src/types.js";

const mockSubscribe = vi.mocked(fal.subscribe);
const mockConfig = vi.mocked(fal.config);
const mockDeleteFromCdn = vi.mocked(deleteFromCdn);

const TEST_FAL_CONFIG: FalConfig = {
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
};

describe("configureFalClient", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    vi.clearAllMocks();
    process.env = { ...originalEnv };
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("configures fal client with FAL_KEY from environment", () => {
    process.env.FAL_KEY = "test-key-123";
    configureFalClient();
    expect(mockConfig).toHaveBeenCalledWith({ credentials: "test-key-123" });
  });

  it("throws when FAL_KEY is not set", () => {
    delete process.env.FAL_KEY;
    expect(() => configureFalClient()).toThrow("FAL_KEY environment variable is required");
  });
});

describe("generateEphemeral", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    vi.clearAllMocks();
    process.env = { ...originalEnv, FAL_KEY: "test-key-123" };
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("calls fal.subscribe with the correct model and input", async () => {
    mockSubscribe.mockResolvedValue({
      data: {
        images: [{ url: "https://fal.media/mock.png", width: 1280, height: 720 }],
        seed: 42,
      },
      requestId: "req-123",
    } as any);

    const result = await generateEphemeral(
      "fal-ai/nano-banana-2",
      { prompt: "test prompt", num_images: 1 },
      TEST_FAL_CONFIG,
    );

    expect(mockSubscribe).toHaveBeenCalledOnce();
    expect(mockSubscribe).toHaveBeenCalledWith(
      "fal-ai/nano-banana-2",
      expect.objectContaining({
        input: { prompt: "test prompt", num_images: 1 },
      }),
    );

    expect(result.images).toHaveLength(1);
    expect(result.images[0].url).toContain("mock.png");
    expect(result.seed).toBe(42);
  });

  it("triggers CDN cleanup when delete_after_download is true", async () => {
    mockSubscribe.mockResolvedValue({
      data: {
        images: [{ url: "https://fal.media/mock.png", width: 1280, height: 720 }],
        seed: 1,
      },
      requestId: "req-123",
    } as any);

    await generateEphemeral(
      "fal-ai/nano-banana-2",
      { prompt: "test" },
      TEST_FAL_CONFIG,
    );

    expect(mockDeleteFromCdn).toHaveBeenCalledOnce();
  });

  it("skips CDN cleanup when delete_after_download is false", async () => {
    mockSubscribe.mockResolvedValue({
      data: {
        images: [{ url: "https://fal.media/mock.png", width: 1280, height: 720 }],
        seed: 1,
      },
      requestId: "req-123",
    } as any);

    const noDeleteConfig = {
      ...TEST_FAL_CONFIG,
      retention: { ...TEST_FAL_CONFIG.retention, delete_after_download: false },
    };

    await generateEphemeral(
      "fal-ai/nano-banana-2",
      { prompt: "test" },
      noDeleteConfig,
    );

    expect(mockDeleteFromCdn).not.toHaveBeenCalled();
  });

  it("handles fal response with empty images gracefully", async () => {
    mockSubscribe.mockResolvedValue({
      data: { images: [], seed: 0 },
      requestId: "req-123",
    } as any);

    const result = await generateEphemeral(
      "fal-ai/nano-banana-2",
      { prompt: "test" },
      TEST_FAL_CONFIG,
    );

    expect(result.images).toEqual([]);
    expect(mockDeleteFromCdn).not.toHaveBeenCalled();
  });
});
