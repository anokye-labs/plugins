/**
 * fal.ai lifecycle header configuration, model presets, CDN expiration settings.
 */
import type { FalConfig, Stage } from "../types.js";

/** Default fal.ai configuration. */
export const DEFAULT_FAL_CONFIG: FalConfig = {
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

/** Model presets per stage with recommended parameters. */
export const MODEL_PRESETS: Record<string, {
  model: string;
  aspect_ratio: string;
  output_format: string;
  quality: number;
}> = {
  draft: {
    model: "fal-ai/nano-banana-2",
    aspect_ratio: "16:9",
    output_format: "jpg",
    quality: 80,
  },
  review: {
    model: "fal-ai/flux-pro",
    aspect_ratio: "16:9",
    output_format: "jpg",
    quality: 90,
  },
  final: {
    model: "fal-ai/flux-pro/kontext/max/multi",
    aspect_ratio: "16:9",
    output_format: "png",
    quality: 100,
  },
  reference: {
    model: "fal-ai/flux-pro/kontext",
    aspect_ratio: "16:9",
    output_format: "png",
    quality: 100,
  },
};

/**
 * Build ephemeral lifecycle headers for a fal.ai request.
 */
export function buildLifecycleHeaders(config: FalConfig): Record<string, string> {
  return {
    "X-Fal-Object-Lifecycle-Preference": JSON.stringify({
      expiration_duration_seconds: config.retention.cdn_expiration_seconds,
    }),
    "X-Fal-Store-IO": config.retention.store_payloads ? "1" : "0",
  };
}

/**
 * Get the model string for a given stage from config.
 */
export function getModelForStage(stage: Stage, config: FalConfig): string {
  const model = config.models[stage as keyof typeof config.models];
  if (!model) {
    throw new Error(`No model configured for stage: ${stage}`);
  }
  return model;
}

/**
 * Get the CDN expiration duration in seconds from config.
 */
export function getCdnExpiration(config: FalConfig): number {
  return config.retention.cdn_expiration_seconds;
}
