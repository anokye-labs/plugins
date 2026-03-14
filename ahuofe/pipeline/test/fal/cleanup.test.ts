import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { deleteFromCdn } from "../../src/fal/cleanup.js";
import type { FalImage } from "../../src/types.js";

describe("deleteFromCdn", () => {
  const originalEnv = process.env;
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    vi.clearAllMocks();
    process.env = { ...originalEnv, FAL_KEY: "test-key-123" };
    globalThis.fetch = vi.fn();
  });

  afterEach(() => {
    process.env = originalEnv;
    globalThis.fetch = originalFetch;
  });

  it("sends DELETE request with correct URL and auth", async () => {
    const mockFetch = vi.mocked(globalThis.fetch);
    mockFetch.mockResolvedValue(new Response(null, { status: 200 }));

    const images: FalImage[] = [
      { url: "https://fal.media/files/abc/image.png" },
    ];

    await deleteFromCdn(images);

    expect(mockFetch).toHaveBeenCalledOnce();
    expect(mockFetch).toHaveBeenCalledWith(
      "https://api.fal.ai/storage/delete",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          Authorization: "Key test-key-123",
          "Content-Type": "application/json",
        }),
        body: JSON.stringify({ url: "https://fal.media/files/abc/image.png" }),
      }),
    );
  });

  it("handles 404 gracefully (file already expired)", async () => {
    const mockFetch = vi.mocked(globalThis.fetch);
    mockFetch.mockResolvedValue(new Response(null, { status: 404 }));

    const images: FalImage[] = [
      { url: "https://fal.media/files/expired/image.png" },
    ];

    // Should not throw
    await expect(deleteFromCdn(images)).resolves.toBeUndefined();
  });

  it("handles fetch errors without throwing", async () => {
    const mockFetch = vi.mocked(globalThis.fetch);
    mockFetch.mockRejectedValue(new Error("Network error"));

    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

    const images: FalImage[] = [
      { url: "https://fal.media/files/broken/image.png" },
    ];

    await expect(deleteFromCdn(images)).resolves.toBeUndefined();
    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining("Network error"),
    );

    warnSpy.mockRestore();
  });

  it("skips images with no URL", async () => {
    const mockFetch = vi.mocked(globalThis.fetch);

    const images: FalImage[] = [
      { url: "" },
      { url: "https://fal.media/files/valid/image.png" },
    ];

    mockFetch.mockResolvedValue(new Response(null, { status: 200 }));

    await deleteFromCdn(images);

    // Only called once for the valid URL
    expect(mockFetch).toHaveBeenCalledOnce();
  });

  it("skips cleanup when FAL_KEY is not set", async () => {
    delete process.env.FAL_KEY;
    const mockFetch = vi.mocked(globalThis.fetch);

    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

    const images: FalImage[] = [
      { url: "https://fal.media/files/abc/image.png" },
    ];

    await deleteFromCdn(images);
    expect(mockFetch).not.toHaveBeenCalled();

    warnSpy.mockRestore();
  });
});
