/**
 * Wrapped fal.ai client with ephemeral lifecycle headers.
 * Ensures images are never permanently stored on fal.ai.
 */
import { fal } from "@fal-ai/client";
import type { FalConfig, FalGenerateResponse } from "../types.js";
import { buildLifecycleHeaders } from "./config.js";
import { deleteFromCdn } from "./cleanup.js";

/**
 * Configure the fal client with credentials from environment.
 */
export function configureFalClient(): void {
  const falKey = process.env.FAL_KEY;
  if (!falKey) {
    throw new Error(
      "FAL_KEY environment variable is required for fal.ai generation",
    );
  }
  fal.config({ credentials: falKey });
}

/**
 * Generate images with ephemeral lifecycle headers.
 * Downloads results and optionally deletes from CDN.
 */
export async function generateEphemeral(
  model: string,
  input: Record<string, unknown>,
  falConfig: FalConfig,
): Promise<FalGenerateResponse> {
  configureFalClient();

  const headers = buildLifecycleHeaders(falConfig);

  const result = await fal.subscribe(model, {
    input,
    ...(headers ? { headers } : {}),
    onQueueUpdate: (update) => {
      if (update.status === "IN_PROGRESS") {
        process.stdout.write(".");
      }
    },
  });

  const data = (result as { data?: FalGenerateResponse }).data ?? result as unknown as FalGenerateResponse;
  const images = data.images ?? [];
  const seed = data.seed;

  // Optionally delete from CDN after obtaining the URLs
  if (falConfig.retention.delete_after_download && images.length > 0) {
    // Fire-and-forget deletion — don't block the pipeline
    deleteFromCdn(images).catch((err) => {
      console.warn(`CDN cleanup warning: ${(err as Error).message}`);
    });
  }

  return { images, seed };
}
