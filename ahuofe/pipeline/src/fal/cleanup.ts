/**
 * Explicit CDN file deletion after download.
 * Belt-and-suspenders approach: even with lifecycle headers,
 * we explicitly delete files from fal.ai CDN.
 */
import type { FalImage } from "../types.js";

const FAL_STORAGE_DELETE_URL = "https://api.fal.ai/storage/delete";

/**
 * Delete images from fal.ai CDN after they've been downloaded.
 * Handles 404 gracefully (file may already be expired).
 */
export async function deleteFromCdn(images: FalImage[]): Promise<void> {
  const falKey = process.env.FAL_KEY;
  if (!falKey) {
    console.warn("FAL_KEY not set — skipping CDN cleanup");
    return;
  }

  for (const image of images) {
    if (!image.url) continue;

    try {
      const response = await fetch(FAL_STORAGE_DELETE_URL, {
        method: "POST",
        headers: {
          Authorization: `Key ${falKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ url: image.url }),
      });

      if (response.ok) {
        // Successfully deleted
      } else if (response.status === 404) {
        // Already expired/deleted — this is fine
      } else {
        console.warn(
          `CDN delete returned ${response.status} for ${image.url}`,
        );
      }
    } catch (err) {
      // Non-fatal: the lifecycle header will handle expiration
      console.warn(
        `CDN delete failed for ${image.url}: ${(err as Error).message}`,
      );
    }
  }
}
