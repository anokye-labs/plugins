import { describe, it, expect } from "vitest";
import {
  DEFAULT_FAL_CONFIG,
  MODEL_PRESETS,
  buildLifecycleHeaders,
  getModelForStage,
  getCdnExpiration,
} from "../../src/fal/config.js";
import { Stage } from "../../src/types.js";

describe("DEFAULT_FAL_CONFIG", () => {
  it("has default retention settings", () => {
    expect(DEFAULT_FAL_CONFIG.retention.cdn_expiration_seconds).toBe(3600);
    expect(DEFAULT_FAL_CONFIG.retention.store_payloads).toBe(false);
    expect(DEFAULT_FAL_CONFIG.retention.delete_after_download).toBe(true);
  });

  it("has all required model presets", () => {
    expect(DEFAULT_FAL_CONFIG.models.draft).toBe("fal-ai/nano-banana-2");
    expect(DEFAULT_FAL_CONFIG.models.review).toBe("fal-ai/flux-pro");
    expect(DEFAULT_FAL_CONFIG.models.final).toBe("fal-ai/flux-pro/kontext/max/multi");
    expect(DEFAULT_FAL_CONFIG.models.reference).toBe("fal-ai/flux-pro/kontext");
    expect(DEFAULT_FAL_CONFIG.models.evaluator).toContain("claude");
  });
});

describe("MODEL_PRESETS", () => {
  it("has presets for each stage", () => {
    expect(MODEL_PRESETS.draft).toBeDefined();
    expect(MODEL_PRESETS.review).toBeDefined();
    expect(MODEL_PRESETS.final).toBeDefined();
    expect(MODEL_PRESETS.reference).toBeDefined();
  });

  it("draft uses jpg output with lower quality", () => {
    expect(MODEL_PRESETS.draft.output_format).toBe("jpg");
    expect(MODEL_PRESETS.draft.quality).toBe(80);
  });

  it("final uses png output with highest quality", () => {
    expect(MODEL_PRESETS.final.output_format).toBe("png");
    expect(MODEL_PRESETS.final.quality).toBe(100);
  });
});

describe("buildLifecycleHeaders", () => {
  it("sets correct ephemeral lifecycle headers", () => {
    const headers = buildLifecycleHeaders(DEFAULT_FAL_CONFIG);

    expect(headers["X-Fal-Object-Lifecycle-Preference"]).toBe(
      JSON.stringify({ expiration_duration_seconds: 3600 }),
    );
    expect(headers["X-Fal-Store-IO"]).toBe("0");
  });

  it("sets Store-IO to 1 when store_payloads is true", () => {
    const config = {
      ...DEFAULT_FAL_CONFIG,
      retention: { ...DEFAULT_FAL_CONFIG.retention, store_payloads: true },
    };

    const headers = buildLifecycleHeaders(config);
    expect(headers["X-Fal-Store-IO"]).toBe("1");
  });

  it("uses custom expiration duration", () => {
    const config = {
      ...DEFAULT_FAL_CONFIG,
      retention: {
        ...DEFAULT_FAL_CONFIG.retention,
        cdn_expiration_seconds: 7200,
      },
    };

    const headers = buildLifecycleHeaders(config);
    const parsed = JSON.parse(headers["X-Fal-Object-Lifecycle-Preference"]);
    expect(parsed.expiration_duration_seconds).toBe(7200);
  });
});

describe("getModelForStage", () => {
  it("returns correct model for each stage", () => {
    expect(getModelForStage(Stage.Draft, DEFAULT_FAL_CONFIG)).toBe(
      "fal-ai/nano-banana-2",
    );
    expect(getModelForStage(Stage.Review, DEFAULT_FAL_CONFIG)).toBe(
      "fal-ai/flux-pro",
    );
    expect(getModelForStage(Stage.Final, DEFAULT_FAL_CONFIG)).toBe(
      "fal-ai/flux-pro/kontext/max/multi",
    );
  });

  it("throws for unknown stage", () => {
    expect(() =>
      getModelForStage("nonexistent" as Stage, DEFAULT_FAL_CONFIG),
    ).toThrow("No model configured for stage");
  });
});

describe("getCdnExpiration", () => {
  it("returns CDN expiration seconds from config", () => {
    expect(getCdnExpiration(DEFAULT_FAL_CONFIG)).toBe(3600);
  });
});
